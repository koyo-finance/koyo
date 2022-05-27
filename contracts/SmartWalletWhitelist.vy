# @version 0.3.3
"""
@title SmartWalletWhitelist
@author Kōyō Finance
@license MIT
"""


interface SmartWalletChecker:
    def check(addr: address) -> bool: nonpayable


implements: SmartWalletChecker


event ApproveWallet:
    wallet: indexed(address)
event RevokeWallet:
    wallet: indexed(address)

event CommitOwnership:
    owner: indexed(address)
event ApplyOwnership:
    owner: indexed(address)

event CommitChecker:
    checker: indexed(address)
event ApplyChecker:
    checker: indexed(address)


wallets: public(HashMap[address, bool])

owner: public(address)  # Can and will be a smart contract
future_owner: public(address)

checker: public(address)
future_checker: public(address)


@external
def __init__():
    """
    @notice Contract constructor.
    """
    self.owner = msg.sender
    self.checker = ZERO_ADDRESS


@internal
def assert_is_owner(addr: address):
    assert addr == self.owner  # dev: owner only


@external
def approve_wallet(wallet: address):
    """
    @notice Allows a smartcontract to execute actions gated by the "SmartWalletWhitelist" check function.
    @param wallet The address that should be approved for interactions.
    """
    self.assert_is_owner(msg.sender)

    self.wallets[wallet] = True

    log ApproveWallet(wallet)


@external
def revoke_wallet(wallet: address):
    """
    @notice Revokes a smartcontracts priviledge to execute actions gated by the "SmartWalletWhitelist" check function.
    @param wallet The address that their interaction privilidges revoked.
    """
    self.assert_is_owner(msg.sender)

    self.wallets[wallet] = False

    log RevokeWallet(wallet)


@external
def check(wallet: address) -> bool:
    """
    @notice Checks if `wallet` is whitelisted.
    @param wallet The address whichs whitelist status should be checked.
    """
    _check: bool = self.wallets[wallet]

    if _check == True:
        return _check
    elif self.checker != ZERO_ADDRESS:
        return SmartWalletChecker(self.checker).check(wallet)
    else:
        return False


@external
def commit_transfer_ownership(addr: address):
    """
    @notice Transfer ownership of the "Minter" contract to `addr`.
    @param addr Address to have ownership transferred to.
    """
    self.assert_is_owner(msg.sender)

    self.future_owner = addr

    log CommitOwnership(addr)


@external
def apply_transfer_ownership():
    """
    @notice Apply ownership transfer.
    """
    self.assert_is_owner(msg.sender)

    _owner: address = self.future_owner
    assert _owner != ZERO_ADDRESS  # dev: owner not set

    self.owner = _owner
    self.future_owner = ZERO_ADDRESS

    log ApplyOwnership(_owner)


@external
def commit_checker(addr: address):
    """
    @notice Set another chained checker to `addr`.
    @param addr Address to which check calls should be chained.
    """
    self.assert_is_owner(msg.sender)

    self.future_checker = addr

    log CommitChecker(addr)


@external
def apply_checker():
    """
    @notice Apply chained checker.
    """
    self.assert_is_owner(msg.sender)

    _checker: address = self.future_checker
    self.checker = _checker

    log ApplyChecker(_checker)
