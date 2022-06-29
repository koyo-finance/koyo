# @version 0.3.3


interface IUniswapV2Pair:
    def permit(owner: address, spender: address, amount: uint256, deadline: uint256, v: uint8, r: bytes32, s: bytes32) -> bool: nonpayable
    def transferFrom(_from : address, _to : address, amount : uint256) -> bool: nonpayable
    def burn(to: address) -> (uint256, uint256): nonpayable

struct JoinPoolRequest:
    assets: DynArray[address, 32]
    maxAmountsIn: DynArray[uint256, 32]
    userData: Bytes[16384]
    fromInternalBalance: bool
interface Vault:
    def joinPool(poolId: bytes32, sender: address, recipient: address, request: JoinPoolRequest): nonpayable


VAULT_ADDRESS: constant(address) = 0x2A4409Cc7d2AE7ca1E3D915337D1B6Ba2350D6a3

OLD_ROUTER_ADDRESS: constant(address) = 0x17C83E2B96ACfb5190d63F5E46d93c107eC0b514
INITCODE_HASH: constant(bytes32) = 0x1db9efb13a1398e31bb71895c392fa1217130f78dc65080174491adcec5da9b9


@internal
@pure
def sort_tokens(_tokenA: address, _tokenB: address) -> (address, address):
    if convert(_tokenA, uint256) < convert(_tokenB, uint256):
        return (_tokenA, _tokenB)
    else:
        return (_tokenB, _tokenA)

@internal
@view
def pair_for_old_router(_tokenA: address, _tokenB: address) -> address:
    token0: address = ZERO_ADDRESS
    token1: address = ZERO_ADDRESS
    (token0, token1) = self.sort_tokens(_tokenA, _tokenB)

    create2_tokens_salt: bytes32 = keccak256(_abi_encode(token0, token1))
    create2_hash: bytes32 = keccak256(concat(0xff, convert(OLD_ROUTER_ADDRESS, bytes20), create2_tokens_salt, INITCODE_HASH))
    create2_addr: address = convert(convert(slice(create2_hash, 12, 20), bytes20), address)

    return create2_addr


@internal
def remove_liquidity(_sender: address, _tokenA: address, _tokenB: address, _minA: uint256, _minB: uint256, _liquidity: uint256) -> (uint256, uint256):
    oolong_pool_address: address = self.pair_for_old_router(_tokenA, _tokenB)
    pair: IUniswapV2Pair = IUniswapV2Pair(oolong_pool_address)

    assert pair.transferFrom(_sender, oolong_pool_address, _liquidity)  # dev: lp token transfer failed

    amount0: uint256 = 0
    amount1: uint256 = 0
    (amount0, amount1) = pair.burn(self)

    token0: address = ZERO_ADDRESS
    token1: address = ZERO_ADDRESS
    (token0, token1) = self.sort_tokens(_tokenA, _tokenB)

    amountA: uint256 = 0
    amountB: uint256 = 0

    if _tokenA == token0:
        amountA = amount0
        amountB = amount1
    else:
        amountA = amount1
        amountB = amount0

    assert amountA >= _minA, "IAA"
    assert amountB >= _minB, "IBA"

    return (amountA, amountB)


@internal
def _migrate(_sender: address, _pool_id: bytes32, _tokenA: address, _tokenB: address, _min_kpt: uint256, _minA: uint256, _minB: uint256, _liquidity: uint256, _deadline: uint256):
    assert _deadline >= block.timestamp  # dev: expired

    amountA: uint256 = 0
    amountB: uint256 = 0
    (amountA, amountB) = self.remove_liquidity(_sender, _tokenA, _tokenB, _minA, _minB, _liquidity)


@external
def migrate_with_permit(_pool_id: bytes32, _tokenA: address, _tokenB: address, _min_kpt: uint256, _minA: uint256, _minB: uint256, _liquidity: uint256, _deadline: uint256, _v: uint8, _r: bytes32, _s: bytes32):
    oolong_pool_address: address = self.pair_for_old_router(_tokenA, _tokenB)
    pair: IUniswapV2Pair = IUniswapV2Pair(oolong_pool_address)

    pair.permit(msg.sender, self, _liquidity, _deadline, _v, _r, _s)
