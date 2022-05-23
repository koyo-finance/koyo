# @version 0.3.3


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


name: public(String[64])
symbol: public(String[32])
decimals: public(uint8)

total_supply: uint256

balanceOf: public(HashMap[address, uint256])
allowances: HashMap[address, HashMap[address, uint256]]


@external
def __init__(_name: String[64], _symbol: String[32], _decimals: uint8):
    """
    @notice Contract constructor
    @param _name Token full name
    @param _symbol Token symbol
    @param _decimals Number of decimals for token
    """
    self.name = _name
    self.symbol = _symbol
    self.decimals = _decimals


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
    @notice Check the amount of tokens that an owner allowed to a spender
    @param _owner The address which owns the funds
    @param _spender The address which will spend the funds
    @return uint256 specifying the amount of tokens still available for the spender
    """
    return self.allowances[_owner][_spender]


@external
def transfer(_to : address, _value : uint256) -> bool:
    """
    @notice Transfer `_value` tokens from `msg.sender` to `_to`
    @dev Vyper does not allow underflows, so the subtraction in
         this function will revert on an insufficient balance
    @param _to The address to transfer to
    @param _value The amount to be transferred
    @return bool success
    """
    assert _to != ZERO_ADDRESS  # dev: transfers to 0x0 are not allowed
    self.balanceOf[msg.sender] -= _value
    self.balanceOf[_to] += _value

    log Transfer(msg.sender, _to, _value)

    return True


@external
def transferFrom(_from : address, _to : address, _value : uint256) -> bool:
    """
     @notice Transfer `_value` tokens from `_from` to `_to`
     @param _from address The address which you want to send tokens from
     @param _to address The address which you want to transfer to
     @param _value uint256 the amount of tokens to be transferred
     @return bool success
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
    @notice Approve `_spender` to transfer `_value` tokens on behalf of `msg.sender`
    @dev Approval may only be from zero -> nonzero or from nonzero -> zero in order
        to mitigate the potential race condition described here:
        https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    @param _spender The address which will spend the funds
    @param _value The amount of tokens to be spent
    @return bool success
    """
    assert _value == 0 or self.allowances[msg.sender][_spender] == 0
    self.allowances[msg.sender][_spender] = _value

    log Approval(msg.sender, _spender, _value)

    return True


@external
def burn(_value: uint256) -> bool:
    """
    @notice Burn `_value` tokens belonging to `msg.sender`
    @dev Emits a Transfer event with a destination of 0x00
    @param _value The amount that will be burned
    @return bool success
    """
    self.balanceOf[msg.sender] -= _value
    self.total_supply -= _value

    log Transfer(msg.sender, ZERO_ADDRESS, _value)

    return True
