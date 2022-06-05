# @version 0.3.3


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
minted: public(HashMap[address, HashMap[address, uint256]])

# minter -> user -> can mint?
allowed_to_mint_for: public(HashMap[address, HashMap[address, bool]])

@external
def __init__(_token: address, _minter: address, _controller: address):
    self.token = _token
    self.minter = _minter
    self.gauge_controller = _controller


@internal
def _mint_for(gauge_addr: address, _for: address):
    assert GaugeController(self.gauge_controller).gauge_types(gauge_addr) >= 0  # dev: gauge is not added

    Gauge(gauge_addr).user_checkpoint(_for)
    total_mint: uint256 = Gauge(gauge_addr).integrate_fraction(_for)
    to_mint: uint256 = total_mint - self.minted[_for][gauge_addr]

    if to_mint != 0:
        Minter(self.minter).mint_and_distribute()
        ERC20(self.token).transfer(_for, to_mint)
        self.minted[_for][gauge_addr] = total_mint


@external
@nonreentrant('lock')
def mint(gauge_addr: address):
    """
    @notice Mint everything which belongs to `msg.sender` and send to them
    @param gauge_addr `Gauge` address to get mintable amount from
    """
    self._mint_for(gauge_addr, msg.sender)


@external
@nonreentrant('lock')
def mint_many(gauge_addrs: DynArray[address, 8]):
    """
    @notice Mint everything which belongs to `msg.sender` across multiple gauges
    @param gauge_addrs List of `Gauge` addresses
    """
    for i in range(8):
        if gauge_addrs[i] == ZERO_ADDRESS:
            continue
        self._mint_for(gauge_addrs[i], msg.sender)
