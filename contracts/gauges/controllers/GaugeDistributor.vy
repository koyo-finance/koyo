# @version 0.3.3
"""
@title Kōyō Finance Gauge Distributor (minter)
@author Kōyō Finance
@license MIT
"""

from vyper.interfaces import ERC20
from ... import Minter


interface GaugeController:
    def gauge_types(addr: address) -> int128: view
interface Gauge:
    def integrate_fraction(addr: address) -> uint256: view
    def user_checkpoint(addr: address) -> bool: nonpayable


token: public(address)
minter: public(address)
gauge_controller: public(address)

# user -> gauge -> value
distributed: public(HashMap[address, HashMap[address, uint256]])

# minter -> user -> can distribute?
allowed_to_distribute_for: public(HashMap[address, HashMap[address, bool]])

@external
def __init__(_token: address, _minter: address, _gauge_controller: address):
    self.token = _token
    self.minter = _minter
    self.gauge_controller = _gauge_controller


@internal
def _distribute_for(gauge_addr: address, _for: address):
    assert GaugeController(self.gauge_controller).gauge_types(gauge_addr) >= 0  # dev: gauge is not added

    Gauge(gauge_addr).user_checkpoint(_for)
    total_mint: uint256 = Gauge(gauge_addr).integrate_fraction(_for)
    to_mint: uint256 = total_mint - self.distributed[_for][gauge_addr]

    if to_mint != 0:
        Minter(self.minter).mint_and_distribute()
        ERC20(self.token).transfer(_for, to_mint)
        self.distributed[_for][gauge_addr] = total_mint


@external
@nonreentrant('lock')
def distribute(gauge_addr: address):
    """
    @notice Mint everything which belongs to `msg.sender` and send to them.
    @param gauge_addr `Gauge` address to get mintable amount from.
    """
    self._distribute_for(gauge_addr, msg.sender)


@external
@nonreentrant('lock')
def distribute_many(gauge_addrs: DynArray[address, 16]):
    """
    @notice Mint everything which belongs to `msg.sender` across multiple gauges.
    @param gauge_addrs List of `Gauge` addresses.
    """
    for gauge_addr in gauge_addrs:
        self._distribute_for(gauge_addr, msg.sender)


@external
@nonreentrant('lock')
def distribute_for(gauge_addr: address, _for: address):
    """
    @notice Distribute tokens for `_for`.
    @dev Only possible when `msg.sender` has been approved via `toggle_approve_distribute`.
    @param gauge_addr `Gauge` address to get distributable amount from.
    @param _for Address to distribute to.
    """
    if self.allowed_to_distribute_for[msg.sender][_for]:
        self._distribute_for(gauge_addr, _for)


@external
def toggle_approve_distribute(distributting_user: address):
    """
    @notice Allow `distributting_user` to distribute for `msg.sender`.
    @param distributting_user Address to toggle permission for.
    """
    self.allowed_to_distribute_for[distributting_user][msg.sender] = not self.allowed_to_distribute_for[distributting_user][msg.sender]
