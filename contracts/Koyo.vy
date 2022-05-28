# @version 0.3.3
"""
@title Kōyō Finance (KYO) token
@author Kōyō Finance
@license MIT
@dev 6_149_520_000 tokens are minter over the period of ~5 years (157680000 seconds).
     Every epoch (1 second), 39 KYO tokens are available to be minted by the "Minter" contract.
"""


from vyper.interfaces import ERC20

implements: ERC20


event Transfer:
    _from: indexed(address)
    _to: indexed(address)
    _value: uint256
event Approval:
    _owner: indexed(address)
    _spender: indexed(address)
    _value: uint256

event Mint:
    minter: indexed(address)
    recipient: indexed(address)
    amount: uint256
    previous_total_supply: uint256
    new_total_supply: uint256

event SetOwnership:
    owner: indexed(address)
event SetMinter:
    minter: indexed(address)


YEAR: constant(uint256) = 365 * 86400

EMISSION_DURATION: constant(uint256) = 5 * YEAR
EMISSION_AMOUNT: constant(uint256) = 6_149_520_000


name: public(String[64])
symbol: public(String[32])
decimals: public(uint256)

total_supply: uint256

balanceOf: public(HashMap[address, uint256])
allowances: HashMap[address, HashMap[address, uint256]]

emission_end: public(uint256)
emission_rate: public(uint256)

emissions_generated: public(uint256)
emissions_last_update_time: public(uint256)

owner: public(address)  # Can and will be a smart contract
future_owner: public(address)

minter: public(address)  # Can and will be a smart contract
future_minter: public(address)


@external
def __init__(_name: String[64], _symbol: String[32], _decimals: uint256):
    """
    @notice Contract constructor.
    @param _name Token full name.
    @param _symbol Token symbol.
    @param _decimals Number of decimals for token.
    """
    ts: uint256 = block.timestamp

    self.owner = msg.sender
    self.minter = msg.sender

    self.name = _name
    self.symbol = _symbol
    self.decimals = _decimals

    self.emission_end = ts + EMISSION_DURATION
    self.emission_rate = (EMISSION_AMOUNT * 10 ** _decimals) / EMISSION_DURATION

    self.emissions_generated = 0
    self.emissions_last_update_time = ts


@internal
@view
def assert_is_owner(addr: address):
    """
    @notice Check if the call is from the owner, revert if not.
    @param addr Address to be checked.
    """
    assert addr == self.owner  # dev: owner only


@internal
@view
def assert_is_minter(addr: address):
    """
    @notice Check if the call is from the designated minter, revert if not.
    @param addr Address to be checked.
    """
    assert addr == self.minter  # dev: minter only


@internal
def _update_emissions() -> uint256:
    total: uint256 = self.emissions_generated

    last_time: uint256 = min(block.timestamp, self.emission_end)
    total += (last_time - self.emissions_last_update_time) * self.emission_rate

    self.emissions_generated = total
    self.emissions_last_update_time = last_time

    return total


@external
@view
def totalSupply() -> uint256:
    """
    @notice Total number of tokens in existence.
    """
    return self.total_supply


@external
@view
def allowance(_owner : address, _spender : address) -> uint256:
    """
    @notice Check the amount of tokens that an owner allowed to a spender.
    @param _owner The address which owns the funds.
    @param _spender The address which will spend the funds.
    @return uint256 specifying the amount of tokens still available for the spender.
    """
    return self.allowances[_owner][_spender]


@external
def transfer(_to : address, _value : uint256) -> bool:
    """
    @notice Transfer `_value` tokens from `msg.sender` to `_to`.
    @dev Vyper does not allow underflows, so the subtraction in
         this function will revert on an insufficient balance.
    @param _to The address to transfer to.
    @param _value The amount to be transferred.
    @return bool success.
    """
    assert _to != ZERO_ADDRESS  # dev: transfers to 0x0 are not allowed
    self.balanceOf[msg.sender] -= _value
    self.balanceOf[_to] += _value

    log Transfer(msg.sender, _to, _value)

    return True


@external
def transferFrom(_from : address, _to : address, _value : uint256) -> bool:
    """
    @notice Transfer `_value` tokens from `_from` to `_to`.
    @param _from address The address which you want to send tokens from.
    @param _to address The address which you want to transfer to.
    @param _value uint256 the amount of tokens to be transferred.
    @return bool success.
    """
    assert _to != ZERO_ADDRESS  # dev: transfers to 0x0 are not allowed
    # NOTE: vyper does not allow underflows
    #       so the following subtraction would revert on insufficient balance
    self.balanceOf[_from] -= _value
    self.balanceOf[_to] += _value
    self.allowances[_from][msg.sender] -= _value

    log Transfer(_from, _to, _value)

    return True


@external
def approve(_spender : address, _value : uint256) -> bool:
    """
    @notice Approve `_spender` to transfer `_value` tokens on behalf of `msg.sender`.
    @dev Approval may only be from zero -> nonzero or from nonzero -> zero in order
        to mitigate the potential race condition described here:
        https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729 .
    @param _spender The address which will spend the funds.
    @param _value The amount of tokens to be spent.
    @return bool success.
    """
    assert _value == 0 or self.allowances[msg.sender][_spender] == 0
    self.allowances[msg.sender][_spender] = _value

    log Approval(msg.sender, _spender, _value)

    return True


@external
def increaseAllowance(_spender: address, _added_value: uint256) -> bool:
    """
    @notice Increase the allowance granted to `_spender` by the caller
    @dev This is alternative to {approve} that can be used as a mitigation for
         the potential race condition
    @param _spender The address which will transfer the funds
    @param _added_value The amount of to increase the allowance
    @return bool success
    """
    allowance: uint256 = self.allowances[msg.sender][_spender] + _added_value
    self.allowances[msg.sender][_spender] = allowance

    log Approval(msg.sender, _spender, allowance)

    return True


@external
def decreaseAllowance(_spender: address, _subtracted_value: uint256) -> bool:
    """
    @notice Decrease the allowance granted to `_spender` by the caller.
    @dev This is alternative to {approve} that can be used as a mitigation for
         the potential race condition.
    @param _spender The address which will transfer the funds.
    @param _subtracted_value The amount of to decrease the allowance.
    @return bool success.
    """
    allowance: uint256 = self.allowances[msg.sender][_spender] - _subtracted_value
    self.allowances[msg.sender][_spender] = allowance

    log Approval(msg.sender, _spender, allowance)

    return True


@external
def mint_available(_to: address) -> bool:
    """
    @notice Mints any available tokens to `_to`.
    @param _to Address to which all available tokens should be minted.
    @return bool success.
    """
    self.assert_is_minter(msg.sender)
    assert _to != ZERO_ADDRESS  # dev: zero address

    amount: uint256 = self._update_emissions()
    _total_supply: uint256 = self.total_supply
    self.total_supply = _total_supply + amount

    self.balanceOf[_to] += amount

    log Transfer(ZERO_ADDRESS, _to, amount)
    log Mint(msg.sender, _to, amount, _total_supply, self.total_supply)

    return True


@external
def burn(_value: uint256) -> bool:
    """
    @notice Burn `_value` tokens belonging to `msg.sender`.
    @dev Emits a Transfer event with a destination of 0x00.
    @param _value The amount that will be burned.
    @return bool success.
    """
    self.balanceOf[msg.sender] -= _value
    self.total_supply -= _value

    log Transfer(msg.sender, ZERO_ADDRESS, _value)

    return True


@external
def set_minter(_minter: address):
    """
    @notice Set the minter address.
    @param _minter Address of the minter.
    """
    self.assert_is_owner(msg.sender)

    self.minter = _minter

    log SetMinter(_minter)


@external
def set_owner(_owner: address):
    """
    @notice Set the new owner.
    @param _owner New owner address.
    """
    self.assert_is_owner(msg.sender)

    self.owner = _owner

    log SetOwnership(_owner)


@external
def set_name(_name: String[64], _symbol: String[32]):
    """
    @notice Change the token name and symbol to `_name` and `_symbol`.
    @dev Only callable by the admin account.
    @param _name New token name.
    @param _symbol New token symbol.
    """
    self.assert_is_owner(msg.sender)

    self.name = _name
    self.symbol = _symbol
