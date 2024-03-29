# @version 0.3.3
"""
@title Voting Escrow
@author Kōyō Finance
@license MIT
@notice Votes have a weight depending on time, so that users are
        committed to the future of (whatever they are voting for).
@dev Vote weight decays linearly over time. Lock time cannot be
     more than `MAXTIME` (~1 year).
     If a lock if forcefully exited the user experiences a 80% loss which is burnt.
"""


from SmartWalletWhitelist import SmartWalletChecker


interface ERC20:
    def decimals() -> uint256: view
    def name() -> String[64]: view
    def symbol() -> String[32]: view
    def approve(spender: address, amount: uint256) -> bool: nonpayable
    def transfer(to: address, amount: uint256) -> bool: nonpayable
    def transferFrom(spender: address, to: address, amount: uint256) -> bool: nonpayable
    def burn(amount: uint256) -> bool: nonpayable

interface Migrator:
    def migrate_lock(addr: address, amount: uint256): nonpayable


# Voting escrow to have time-weighted votes
# Votes have a weight depending on time, so that users are committed
# to the future of (whatever they are voting for).
# The weight in this implementation is linear, and lock cannot be more than maxtime:
# w ^
# 1 +        /
#   |      /
#   |    /
#   |  /
#   |/
# 0 +--------+------> time
#       maxtime (1 year?)
#
# If at any point the user decides to forcefully withdraw they will do so at a 80% loss of their initial locked amount.
# The 80% lost will be burnt and removed from circulation.

struct Point:
    bias: int128
    slope: int128  # - dweight / dt
    ts: uint256
    blk: uint256  # block
# We cannot really do block numbers per se b/c slope is per time, not per block
# and per block could be fairly bad b/c Ethereum changes blocktimes.
# What we can do is to extrapolate ***At functions

struct LockedBalance:
    amount: int128
    end: uint256


event Initialized:
    token: address

event Deposit:
    deposit_from: indexed(address)
    provider: indexed(address)
    value: uint256
    locktime: indexed(uint256)
    type: int128
    ts: uint256
event Supply:
    prevSupply: uint256
    supply: uint256
event Migrate:
    account: indexed(address)
    amount: uint256
    to: indexed(address)
event Withdraw:
    provider: indexed(address)
    value: uint256
    ts: uint256
event PenaltyApplied:
    provider: indexed(address)
    value: uint256
    penalty: uint256
    ts: uint256

event CommitOwnership:
    owner: indexed(address)
event ApplyOwnership:
    owner: indexed(address)

event CommitSmartWalletChecker:
    checker: indexed(address)
event ApplySmartWalletChecker:
    checker: indexed(address)

event CommitNextVeContract:
    ve: indexed(address)
event ApplyNextVeContract:
    ve: indexed(address)


DEPOSIT_FOR_TYPE: constant(int128) = 0
CREATE_LOCK_TYPE: constant(int128) = 1
INCREASE_LOCK_AMOUNT: constant(int128) = 2
INCREASE_UNLOCK_TIME: constant(int128) = 3

DAY: constant(uint256) = 86400  # 1 day
WEEK: constant(uint256) = 7 * DAY  # all future times are rounded by week
MAXTIME: constant(uint256) = 365 * DAY  # 1 year
MAXTIME_I128: constant(int128) = 365 * DAY  # 1 year
MULTIPLIER: constant(uint256) = 10 ** 18

PENALTY_RATIO: constant(uint256) = MULTIPLIER * 1 / 5


token: public(address)

name: public(String[64])
symbol: public(String[32])
version: public(String[32])
decimals: public(uint256)
supply: public(uint256)

locked: public(HashMap[address, LockedBalance])

epoch: public(uint256)
point_history: public(Point[100000000000000000000000000000])  # epoch -> unsigned point
user_point_history: public(HashMap[address, Point[1000000000]])  # user -> Point[user_epoch]
user_point_epoch: public(HashMap[address, uint256])
slope_changes: public(HashMap[uint256, int128])  # time -> signed slope change

owner: public(address)  # Can and will be a smart contract
future_owner: public(address)

# Aragon's view methods for compatibility
controller: public(address)
transfersEnabled: public(bool)

smart_wallet_checker: public(address)
future_smart_wallet_checker: public(address)

next_ve_contract: public(address)
queued_next_ve_contract: public(address)
migration: public(bool)


@external
def __init__(token_addr: address, _name: String[64], _symbol: String[32], _version: String[32]):
    """
    @notice Contract constructor.
    @param token_addr `Koyo` (KYO) token address.
    @param _name Token name.
    @param _symbol Token symbol.
    @param _version Contract version - required for Aragon compatibility.
    """
    self.owner = msg.sender

    self.token = token_addr

    _decimals: uint256 = ERC20(token_addr).decimals()
    assert _decimals <= 255
    self.decimals = _decimals

    self.name = _name
    self.symbol = _symbol
    self.version = _version

    self.point_history[0].blk = block.number
    self.point_history[0].ts = block.timestamp

    self.controller = msg.sender
    self.transfersEnabled = True

    log Initialized(token_addr)


@internal
@view
def assert_is_owner(addr: address):
    """
    @notice Check if the call is from the owner, revert if not.
    @param addr Address to be checked.
    """
    assert addr == self.owner  # dev: owner only


@internal
def assert_not_contract(addr: address):
    """
    @notice Check if the call is from a whitelisted smart contract, revert if not.
    @param addr Address to be checked.
    """
    if addr != tx.origin:
        checker: address = self.smart_wallet_checker
        if checker != ZERO_ADDRESS:
            if SmartWalletChecker(checker).check(addr):
                return
        raise "SCDNA"


@external
@view
def get_last_user_slope(addr: address) -> int128:
    """
    @notice Get the most recently recorded rate of voting power decrease for `addr`.
    @dev Returns 0 if the contract has entered a migration.
    @param addr Address of the user wallet.
    @return Value of the slope.
    """
    if self.migration:
        return 0

    uepoch: uint256 = self.user_point_epoch[addr]
    return self.user_point_history[addr][uepoch].slope


@external
@view
def user_point_history__ts(_addr: address, _idx: uint256) -> uint256:
    """
    @notice Get the timestamp for checkpoint `_idx` for `_addr`.
    @dev Returns 0 if the contract has entered a migration.
    @param _addr User wallet address.
    @param _idx User epoch number.
    @return Epoch time of the checkpoint.
    """
    if self.migration:
        return 0

    return self.user_point_history[_addr][_idx].ts


@external
@view
def locked__end(_addr: address) -> uint256:
    """
    @notice Get timestamp when `_addr`'s lock finishes.
    @dev Returns 0 if the contract has entered a migration.
    @param _addr User wallet.
    @return Epoch time of the lock end.
    """
    if self.migration:
        return 0

    return self.locked[_addr].end


@internal
def _checkpoint(addr: address, old_locked: LockedBalance, new_locked: LockedBalance):
    """
    @notice Record global and per-user data to checkpoint.
    @param addr User's wallet address. No user checkpoint if 0x0.
    @param old_locked Pevious locked amount / end lock time for the user.
    @param new_locked New locked amount / end lock time for the user.
    """
    u_old: Point = empty(Point)
    u_new: Point = empty(Point)
    old_dslope: int128 = 0
    new_dslope: int128 = 0
    _epoch: uint256 = self.epoch

    if addr != ZERO_ADDRESS:
        # Calculate slopes and biases
        # Kept at zero when they have to
        if old_locked.end > block.timestamp and old_locked.amount > 0:
            u_old.slope = old_locked.amount / MAXTIME_I128
            u_old.bias = u_old.slope * convert(old_locked.end - block.timestamp, int128)
        if new_locked.end > block.timestamp and new_locked.amount > 0:
            u_new.slope = new_locked.amount / MAXTIME_I128
            u_new.bias = u_new.slope * convert(new_locked.end - block.timestamp, int128)

        # Read values of scheduled changes in the slope
        # old_locked.end can be in the past and in the future
        # new_locked.end can ONLY by in the FUTURE unless everything expired: than zeros
        old_dslope = self.slope_changes[old_locked.end]
        if new_locked.end != 0:
            if new_locked.end == old_locked.end:
                new_dslope = old_dslope
            else:
                new_dslope = self.slope_changes[new_locked.end]

    last_point: Point = Point({bias: 0, slope: 0, ts: block.timestamp, blk: block.number})
    if _epoch > 0:
        last_point = self.point_history[_epoch]
    last_checkpoint: uint256 = last_point.ts
    # initial_last_point is used for extrapolation to calculate block number
    # (approximately, for *At methods) and save them
    # as we cannot figure that out exactly from inside the contract
    initial_last_point: Point = last_point
    block_slope: uint256 = 0  # dblock/dt
    if block.timestamp > last_point.ts:
        block_slope = MULTIPLIER * (block.number - last_point.blk) / (block.timestamp - last_point.ts)
    # If last point is already recorded in this block, slope=0
    # But that's ok b/c we know the block in such case

    # Go over weeks to fill history and calculate what the current point is
    t_i: uint256 = (last_checkpoint / WEEK) * WEEK
    for i in range(255):
        # Hopefully it won't happen that this won't get used in 5 years!
        # If it does, users will be able to withdraw but vote weight will be broken
        t_i += WEEK
        d_slope: int128 = 0
        if t_i > block.timestamp:
            t_i = block.timestamp
        else:
            d_slope = self.slope_changes[t_i]
        last_point.bias -= last_point.slope * convert(t_i - last_checkpoint, int128)
        last_point.slope += d_slope
        if last_point.bias < 0:  # This can happen
            last_point.bias = 0
        if last_point.slope < 0:  # This cannot happen - just in case
            last_point.slope = 0
        last_checkpoint = t_i
        last_point.ts = t_i
        last_point.blk = initial_last_point.blk + block_slope * (t_i - initial_last_point.ts) / MULTIPLIER
        _epoch += 1
        if t_i == block.timestamp:
            last_point.blk = block.number
            break
        else:
            self.point_history[_epoch] = last_point

    self.epoch = _epoch
    # Now point_history is filled until t=now

    if addr != ZERO_ADDRESS:
        # If last point was in this block, the slope change has been applied already
        # But in such case we have 0 slope(s)
        last_point.slope += (u_new.slope - u_old.slope)
        last_point.bias += (u_new.bias - u_old.bias)
        if last_point.slope < 0:
            last_point.slope = 0
        if last_point.bias < 0:
            last_point.bias = 0

    # Record the changed point into history
    self.point_history[_epoch] = last_point

    if addr != ZERO_ADDRESS:
        # Schedule the slope changes (slope is going down)
        # We subtract new_user_slope from [new_locked.end]
        # and add old_user_slope to [old_locked.end]
        if old_locked.end > block.timestamp:
            # old_dslope was <something> - u_old.slope, so we cancel that
            old_dslope += u_old.slope
            if new_locked.end == old_locked.end:
                old_dslope -= u_new.slope  # It was a new deposit, not extension
            self.slope_changes[old_locked.end] = old_dslope

        if new_locked.end > block.timestamp:
            if new_locked.end > old_locked.end:
                new_dslope -= u_new.slope  # old slope disappeared at this point
                self.slope_changes[new_locked.end] = new_dslope
            # else: we recorded it already in old_dslope

        # Now handle user history
        user_epoch: uint256 = self.user_point_epoch[addr] + 1

        self.user_point_epoch[addr] = user_epoch
        u_new.ts = block.timestamp
        u_new.blk = block.number
        self.user_point_history[addr][user_epoch] = u_new


@external
def checkpoint():
    """
    @notice Record global data to checkpoint.
    """
    self._checkpoint(ZERO_ADDRESS, empty(LockedBalance), empty(LockedBalance))


@internal
def _deposit_for(_from: address, _addr: address, _value: uint256, unlock_time: uint256, locked_balance: LockedBalance, type: int128):
    """
    @notice Deposit and lock tokens for a user.
    @dev A deposit cannot be made if the "VotingEscrow" contract has started a migration.
    @param _from Address from which the tokens are transferred.
    @param _addr User's wallet address.
    @param _value Amount to deposit.
    @param unlock_time New time when to unlock the tokens, or 0 if unchanged.
    @param locked_balance Previous locked amount / timestamp.
    """
    assert(self.migration == False) # dev: must migrate

    _locked: LockedBalance = locked_balance
    supply_before: uint256 = self.supply

    self.supply = supply_before + _value
    old_locked: LockedBalance = _locked
    # Adding to existing lock, or if a lock is expired - creating a new one
    _locked.amount += convert(_value, int128)
    if unlock_time != 0:
        _locked.end = unlock_time
    self.locked[_addr] = _locked

    # Possibilities:
    # Both old_locked.end could be current or expired (>/< block.timestamp)
    # value == 0 (extend lock) or value > 0 (add to lock or extend lock)
    # _locked.end > block.timestamp (always)
    self._checkpoint(_addr, old_locked, _locked)

    if _value != 0:
        assert ERC20(self.token).transferFrom(_from, self, _value)

    log Deposit(_from, _addr, _value, _locked.end, type, block.timestamp)
    log Supply(supply_before, supply_before + _value)


@internal
def _create_lock_for(_from: address, _addr: address, _value: uint256, _unlock_time: uint256):
    unlock_time: uint256 = (_unlock_time / WEEK) * WEEK  # Locktime is rounded down to weeks
    _locked: LockedBalance = self.locked[_addr]

    assert _value > 0  # dev: need non-zero value
    assert _locked.amount == 0, "W"
    assert unlock_time > block.timestamp, "LBF"
    assert unlock_time <= block.timestamp + MAXTIME, "VLABT"

    self._deposit_for(_from, _addr, _value, unlock_time, _locked, CREATE_LOCK_TYPE)


@external
@nonreentrant('lock')
def deposit_for(_addr: address, _value: uint256):
    """
    @notice Deposit `_value` tokens for `_addr` and add to the lock.
    @dev Anyone (even a smart contract) can deposit for someone else, but
         cannot extend their locktime and deposit for a brand new user.
    @param _addr User's wallet address.
    @param _value Amount to add to user's lock.
    """
    _locked: LockedBalance = self.locked[_addr]

    assert _value > 0  # dev: need non-zero value
    assert _locked.amount > 0, "NELF"
    assert _locked.end > block.timestamp, "CAEL-W"

    self._deposit_for(msg.sender, _addr, _value, 0, _locked, DEPOSIT_FOR_TYPE)


@external
@nonreentrant('lock')
def create_lock(_value: uint256, _unlock_time: uint256):
    """
    @notice Deposit `_value` tokens for `msg.sender` and lock until `_unlock_time`.
    @dev This action cannot be performed by a smart contract
         that isn't whitelisted in the "SmartWalletWhitelist" contract.
    @param _value Amount to deposit.
    @param _unlock_time Epoch time when tokens unlock, rounded down to whole weeks.
    """
    self.assert_not_contract(msg.sender)

    self._create_lock_for(msg.sender, msg.sender, _value, _unlock_time)


@external
@nonreentrant('lock')
def create_lock_for(_addr: address, _value: uint256, _unlock_time: uint256):
    """
    @notice Deposit `_value` tokens for `_addr` and lock until `_unlock_time`.
    @dev This action is only performable by the contract owner.
    @param _addr Address for which to create the lock.
    @param _value Amount to deposit.
    @param _unlock_time Epoch time when tokens unlock, rounded down to whole weeks.
    """
    self.assert_is_owner(msg.sender)

    self._create_lock_for(msg.sender, _addr, _value, _unlock_time)


@external
@nonreentrant('lock')
def increase_amount(_value: uint256):
    """
    @notice Deposit `_value` additional tokens for `msg.sender`
            without modifying the unlock time.
    @dev This action cannot be performed by a smart contract
         that isn't whitelisted in the "SmartWalletWhitelist" contract.
    @param _value Amount of tokens to deposit and add to the lock.
    """
    self.assert_not_contract(msg.sender)

    _locked: LockedBalance = self.locked[msg.sender]

    assert _value > 0  # dev: need non-zero value
    assert _locked.amount > 0, "NELF"
    assert _locked.end > block.timestamp, "CAEL-W"

    self._deposit_for(msg.sender, msg.sender, _value, 0, _locked, INCREASE_LOCK_AMOUNT)


@external
@nonreentrant('lock')
def increase_unlock_time(_unlock_time: uint256):
    """
    @notice Extend the unlock time for `msg.sender` to `_unlock_time`.
    @dev This action cannot be performed by a smart contract
         that isn't whitelisted in the "SmartWalletWhitelist" contract.
    @param _unlock_time New epoch time for unlocking.
    """
    self.assert_not_contract(msg.sender)

    _locked: LockedBalance = self.locked[msg.sender]
    unlock_time: uint256 = (_unlock_time / WEEK) * WEEK  # Locktime is rounded down to weeks

    assert _locked.end > block.timestamp, "CAEL-W"
    assert _locked.amount > 0, "NELF"
    assert unlock_time > _locked.end, "COILT"
    assert unlock_time <= block.timestamp + MAXTIME, "VLABT"

    self._deposit_for(msg.sender, msg.sender, 0, unlock_time, _locked, INCREASE_UNLOCK_TIME)


@external
@nonreentrant('lock')
def withdraw():
    """
    @notice Withdraw all tokens for `msg.sender`.
    @dev Only possible if the lock has expired.
    """
    _locked: LockedBalance = self.locked[msg.sender]
    assert block.timestamp >= _locked.end, "LNE"
    value: uint256 = convert(_locked.amount, uint256)

    old_locked: LockedBalance = _locked
    _locked.end = 0
    _locked.amount = 0
    self.locked[msg.sender] = _locked
    supply_before: uint256 = self.supply
    self.supply = supply_before - value

    # old_locked can have either expired <= timestamp or zero end
    # _locked has only 0 end
    # Both can have >= 0 amount
    self._checkpoint(msg.sender, old_locked, _locked)

    assert ERC20(self.token).transfer(msg.sender, value)

    log Withdraw(msg.sender, value, block.timestamp)
    log Supply(supply_before, supply_before - value)


@external
@nonreentrant('lock')
def force_withdraw():
    """
    @notice Withdraw all tokens for `msg.sender` before their lock has expired.
            Forcefully withdrawing incours a 80% penalty which gets permanently burnt.
    @dev Only possible before a users lock ends and only if the "VotingEscow" hasn't entered a migration.
    """
    assert self.migration == False  # dev: must not be migrating

    _locked: LockedBalance = self.locked[msg.sender]
    assert block.timestamp < _locked.end, "LE"

    value: uint256 = convert(_locked.amount, uint256)

    old_locked: LockedBalance = _locked
    _locked.end = 0
    _locked.amount = 0
    self.locked[msg.sender] = _locked
    supply_before: uint256 = self.supply
    self.supply = supply_before - value

    # old_locked can have either expired <= timestamp or zero end
    # _locked has only 0 end
    # Both can have >= 0 amount
    self._checkpoint(msg.sender, old_locked, _locked)

    penalised: uint256 = value * PENALTY_RATIO / MULTIPLIER
    assert ERC20(self.token).transfer(msg.sender, penalised)
    assert ERC20(self.token).burn(value - penalised)

    log Withdraw(msg.sender, value, block.timestamp)
    log PenaltyApplied(msg.sender, value, penalised, block.timestamp)
    log Supply(supply_before, supply_before - value)


@external
@nonreentrant('lock')
def migrate():
    """
    @notice Transfers the lock of `msg.sender` to a new ve contract.
    """
    assert self.next_ve_contract != ZERO_ADDRESS # dev: no next ve contract

    _locked: LockedBalance = self.locked[msg.sender]
    assert block.timestamp < _locked.end, "LE"
    value: uint256 = convert(_locked.amount, uint256)

    ERC20(self.token).approve(self.next_ve_contract, value)
    Migrator(self.next_ve_contract).migrate_lock(msg.sender, value)

    old_locked: LockedBalance = _locked
    _locked.end = 0
    _locked.amount = 0
    self.locked[msg.sender] = _locked
    supply_before: uint256 = self.supply
    self.supply = supply_before - value
    self._checkpoint(msg.sender, old_locked, _locked)

    log Migrate(msg.sender, value, self.next_ve_contract)


# The following ERC20/minime-compatible methods are not real balanceOf and supply!
# They measure the weights for the purpose of voting, so they don't represent
# real coins.

@internal
@view
def find_block_epoch(_block: uint256, max_epoch: uint256) -> uint256:
    """
    @notice Binary search to estimate timestamp for block number.
    @param _block Block to find.
    @param max_epoch Don't go beyond this epoch.
    @return Approximate timestamp for block.
    """
    # Binary search
    _min: uint256 = 0
    _max: uint256 = max_epoch
    for i in range(128):  # Will be always enough for 128-bit numbers
        if _min >= _max:
            break
        _mid: uint256 = (_min + _max + 1) / 2
        if self.point_history[_mid].blk <= _block:
            _min = _mid
        else:
            _max = _mid - 1
    return _min


@internal
@view
def balance_of(addr: address, _t: uint256 = block.timestamp) -> uint256:
    """
    @notice Get the current voting power for `msg.sender`.
    @dev Returns 0 if the contract has entered a migration.
    @param addr User wallet address.
    @param _t Epoch time to return voting power at.
    @return User voting power.
    """
    if self.migration:
        return 0

    _epoch: uint256 = self.user_point_epoch[addr]
    if _epoch == 0:
        return 0
    else:
        last_point: Point = self.user_point_history[addr][_epoch]
        last_point.bias -= last_point.slope * convert(_t - last_point.ts, int128)
        if last_point.bias < 0:
            last_point.bias = 0
        return convert(last_point.bias, uint256)


@external
@view
def balanceOf(addr: address, _t: uint256 = block.timestamp) -> uint256:
    """
    @notice Get the current voting power for `msg.sender`.
    @dev Adheres to the ERC20 `balanceOf` interface for Aragon compatibility.
         Returns 0 if the contract has entered a migration.
    @param addr User wallet address.
    @param _t Epoch time to return voting power at.
    @return User voting power.
    """
    return self.balance_of(addr, _t)


@internal
@view
def balance_of_at(addr: address, _block: uint256) -> uint256:
    """
    @notice Measure voting power of `addr` at block height `_block`.
    @dev Returns 0 if the contract has entered a migration.
    @param addr User's wallet address.
    @param _block Block to calculate the voting power at.
    @return Voting power.
    """
    if self.migration:
        return 0

    # Copying and pasting totalSupply code because Vyper cannot pass by
    # reference yet
    assert _block <= block.number

    # Binary search
    _min: uint256 = 0
    _max: uint256 = self.user_point_epoch[addr]
    for i in range(128):  # Will be always enough for 128-bit numbers
        if _min >= _max:
            break
        _mid: uint256 = (_min + _max + 1) / 2
        if self.user_point_history[addr][_mid].blk <= _block:
            _min = _mid
        else:
            _max = _mid - 1

    upoint: Point = self.user_point_history[addr][_min]

    max_epoch: uint256 = self.epoch
    _epoch: uint256 = self.find_block_epoch(_block, max_epoch)
    point_0: Point = self.point_history[_epoch]
    d_block: uint256 = 0
    d_t: uint256 = 0
    if _epoch < max_epoch:
        point_1: Point = self.point_history[_epoch + 1]
        d_block = point_1.blk - point_0.blk
        d_t = point_1.ts - point_0.ts
    else:
        d_block = block.number - point_0.blk
        d_t = block.timestamp - point_0.ts
    block_time: uint256 = point_0.ts
    if d_block != 0:
        block_time += d_t * (_block - point_0.blk) / d_block

    upoint.bias -= upoint.slope * convert(block_time - upoint.ts, int128)
    if upoint.bias >= 0:
        return convert(upoint.bias, uint256)
    else:
        return 0


@external
@view
def balanceOfAt(addr: address, _block: uint256) -> uint256:
    """
    @notice Measure voting power of `addr` at block height `_block`.
    @dev Adheres to MiniMe `balanceOfAt` interface: https://github.com/Giveth/minime .
         Returns 0 if the contract has entered a migration.
    @param addr User's wallet address.
    @param _block Block to calculate the voting power at.
    @return Voting power.
    """
    return self.balance_of_at(addr, _block)


@internal
@view
def supply_at(point: Point, t: uint256) -> uint256:
    """
    @notice Calculate total voting power at some point in the past.
    @dev Returns 0 if the contract has entered a migration.
    @param point The point (bias/slope) to start search from.
    @param t Time to calculate the total voting power at.
    @return Total voting power at that time.
    """
    if self.migration:
        return 0

    last_point: Point = point
    t_i: uint256 = (last_point.ts / WEEK) * WEEK
    for i in range(255):
        t_i += WEEK
        d_slope: int128 = 0
        if t_i > t:
            t_i = t
        else:
            d_slope = self.slope_changes[t_i]
        last_point.bias -= last_point.slope * convert(t_i - last_point.ts, int128)
        if t_i == t:
            break
        last_point.slope += d_slope
        last_point.ts = t_i

    if last_point.bias < 0:
        last_point.bias = 0
    return convert(last_point.bias, uint256)


@external
@view
def totalSupply(t: uint256 = block.timestamp) -> uint256:
    """
    @notice Calculate total voting power.
    @dev Adheres to the ERC20 `totalSupply` interface for Aragon compatibility.
         Returns 0 if the contract has entered a migration.
    @return Total voting power.
    """
    _epoch: uint256 = self.epoch
    last_point: Point = self.point_history[_epoch]
    return self.supply_at(last_point, t)


@external
@view
def totalSupplyAt(_block: uint256) -> uint256:
    """
    @notice Calculate total voting power at some point in the past.
    @dev Returns 0 if the contract has entered a migration.
    @param _block Block to calculate the total voting power at.
    @return Total voting power at `_block`.
    """
    if self.migration:
        return 0

    assert _block <= block.number
    _epoch: uint256 = self.epoch
    target_epoch: uint256 = self.find_block_epoch(_block, _epoch)

    point: Point = self.point_history[target_epoch]
    dt: uint256 = 0
    if target_epoch < _epoch:
        point_next: Point = self.point_history[target_epoch + 1]
        if point.blk != point_next.blk:
            dt = (_block - point.blk) * (point_next.ts - point.ts) / (point_next.blk - point.blk)
    else:
        if point.blk != block.number:
            dt = (_block - point.blk) * (block.timestamp - point.ts) / (block.number - point.blk)
    # Now dt contains info on how far are we beyond point

    return self.supply_at(point, point.ts + dt)


# These methods are for compatiblity with Governor Bravo.

@external
@view
def getCurrentVotes(addr: address) -> uint256:
    """
    @notice Get the current voting power for `msg.sender`.
    @dev Adheres to Compounds `getCurrentVotes` interface: https://github.com/compound-finance/compound-protocol .
         Returns 0 if a migration is active.
    @param addr User wallet address.
    @return User voting power.
    """
    return self.balance_of(addr)


@external
@view
def getPriorVotes(addr: address, _block: uint256) -> uint256:
    """
    @notice Measure voting power of `addr` at block number `_block`.
    @dev Adheres to Compounds `getPriorVotes` interface: https://github.com/compound-finance/compound-protocol .
         Returns 0 if a migration is active.
    @param addr User's wallet address.
    @param _block Block to calculate the voting power at.
    @return User voting power at `_block`.
    """
    return self.balance_of_at(addr, _block)


# Aragon - Dummy methods for compatibility

@external
def changeController(_newController: address):
    """
    @dev Dummy method required for Aragon compatibility.
    """
    assert msg.sender == self.controller
    self.controller = _newController


# Ownership - Transfer contract ownership/admin

@external
def commit_transfer_ownership(addr: address):
    """
    @notice Transfer ownership of VotingEscrow contract to `addr`.
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


# SmartWalletChecker - Switch contracts

@external
def commit_smart_wallet_checker(addr: address):
    """
    @notice Set an external contract to check for approved smart contract wallets.
    @param addr Address of Smart contract checker.
    """
    self.assert_is_owner(msg.sender)

    self.future_smart_wallet_checker = addr

    log CommitSmartWalletChecker(addr)


@external
def apply_smart_wallet_checker():
    """
    @notice Apply setting external contract to check approved smart contract wallets.
    """
    self.assert_is_owner(msg.sender)

    _checker: address = self.future_smart_wallet_checker
    self.smart_wallet_checker = _checker

    log ApplySmartWalletChecker(_checker)


# Migrating to a new veKYO contract

@external
def commit_next_ve_contract(addr: address):
    """
    @notice Queues a new ve contract to replace the current one (self).
    @param addr Address of the new ve contract.
    """
    self.assert_is_owner(msg.sender)

    self.queued_next_ve_contract = addr

    log CommitNextVeContract(addr)


@external
def apply_next_ve_contract():
    """
    @notice Apply the queued ve contract and set migration to True.
    """
    self.assert_is_owner(msg.sender)

    next: address = self.queued_next_ve_contract

    assert next != ZERO_ADDRESS

    self.next_ve_contract = next
    self.migration = True
    self.queued_next_ve_contract = ZERO_ADDRESS

    log ApplyNextVeContract(next)
