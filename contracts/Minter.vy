# @version 0.3.3
"""
@title Kōyō Minter and Distributooooor
@author Kōyō Finance
@license MIT
@dev KYO tokens claimed by the minter are split between 9 addresses.
        - 64% go to an emissions distributor contract;
        - 10% go to the treasury;
        - 6% go to each of the 4 team members;
        - 0.5% go to each of the 2 advisors;
        - 1% goes to the BobaBAR.
"""


from vyper.interfaces import ERC20


interface MintableERC20:
    def mint_available(to: address) -> bool: nonpayable


event Initialized:
    token: address
    addresses_emission: address[1]
    addresses_treasury: address[1]
    addresses_team_members: address[4]
    addresses_advisors: address[2]
    addresses_boba_bar: address[1]

event MintAvailable:
    amount: uint256
    previous_balance: uint256
    ts: uint256
event Distribute:
    amount: uint256

event CommitOwnership:
    owner: indexed(address)
event ApplyOwnership:
    owner: indexed(address)


SHARE__DENOMINATOR: constant(uint256) = 10 ** 10

SHARE_EMISSIONS: constant(uint256) = 6_400_000_000 # 64%
SHARE_TREASURY: constant(uint256) = 1_000_000_000 # 10%
SHARE_TEAM_MEMBER: constant(uint256) = 600_000_000 # 6% - 24% total (4 members)
SHARE_ADVISOR: constant(uint256) = 50_000_000 # 0.5% - 1% total (2 advisors)
SHARE_BOBA_BAR: constant(uint256) = 100_000_000 # 1%


token: public(address)

addresses_emission: public(address[1])
addresses_treasury: public(address[1])
addresses_team_members: public(address[4])
addresses_advisors: public(address[2])
addresses_boba_bar: public(address[1])

owner: public(address)  # Can and will be a smart contract
future_owner: public(address)


@external
def __init__(
    _token: address,
    _addresses_emission: address[1],
    _addresses_treasury: address[1],
    _addresses_team_members: address[4],
    _addresses_advisors: address[2],
    _addresses_boba_bar: address[1]
):
    """
    @notice Contract constructor.
    @param _token `Koyo` (KYO) token address.
    @param _addresses_emission Address of the emissions distributor.
    @param _addresses_treasury Address of the Kōyō Finance treasury.
    @param _addresses_team_members Addresses of all team members.
    @param _addresses_advisors Addresses of the 2 participating advisors.
    @param _addresses_boba_bar Address of the BobaBAR or BobaDAO.
    """
    self.owner = msg.sender

    self.token = _token

    self.addresses_emission = _addresses_emission
    self.addresses_treasury = _addresses_treasury
    self.addresses_team_members = _addresses_team_members
    self.addresses_advisors = _addresses_advisors
    self.addresses_boba_bar = _addresses_boba_bar

    log Initialized(_token, _addresses_emission, _addresses_treasury, _addresses_team_members, _addresses_advisors, _addresses_boba_bar)


@internal
@view
def assert_is_owner(addr: address):
    """
    @notice Check if the call is from the owner, revert if not.
    @param addr Address to be checked.
    """
    assert addr == self.owner  # dev: owner only


@internal
def _distribute_balance():
    _token: ERC20 = ERC20(self.token)
    _balance: uint256 = _token.balanceOf(self)

    emission_amount: uint256 = _balance * SHARE_EMISSIONS / SHARE__DENOMINATOR
    treasury_amount: uint256 = _balance * SHARE_TREASURY / SHARE__DENOMINATOR
    team_member_amount: uint256 = _balance * SHARE_TEAM_MEMBER / SHARE__DENOMINATOR
    advisor_amount: uint256 = _balance * SHARE_ADVISOR / SHARE__DENOMINATOR
    boba_bar_amount: uint256 = _balance * SHARE_BOBA_BAR / SHARE__DENOMINATOR

    for emission_address in self.addresses_emission:
        assert _token.transfer(emission_address, emission_amount)

    for treasury_address in self.addresses_treasury:
        assert _token.transfer(treasury_address, treasury_amount)

    for team_member_address in self.addresses_team_members:
        assert _token.transfer(team_member_address, team_member_amount)

    for advisor_address in self.addresses_advisors:
        assert _token.transfer(advisor_address, advisor_amount)

    for boba_bar_address in self.addresses_boba_bar:
        assert _token.transfer(boba_bar_address, boba_bar_amount)

    log Distribute(_balance)


@internal
def _mint_available():
    _token: ERC20 = ERC20(self.token)
    _balance: uint256 = _token.balanceOf(self)

    assert MintableERC20(self.token).mint_available(self)

    _balance_claimed: uint256 = _token.balanceOf(self)

    log MintAvailable(_balance_claimed - _balance, _balance, block.timestamp)


@external
def distribute_balance():
    """
    @notice Distributes the "Minter" contracts KYO balance to addresses_emission, addresses_treasury, addresses_team_members, addresses_advisors, and addresses_boba_bar.
    @dev Anyone is allowed to trigger this as the distribution targets are stored in the contract and cannot be influenced externally.
    """
    self._distribute_balance()


@external
def mint_available():
    """
    @notice Mint any available tokens from the underlying "Koyo" contract.
    @dev Anyone is allowed to trigger this as the mint target is the "Minter" contract itself.
    """
    self._mint_available()


@external
def mint_and_distribute():
    """
    @notice Mint any available tokens from the underlying "Koyo" (KYO) contract and distribute the "Minter" contracts balance to addresses_emission, addresses_treasury, addresses_team_members, addresses_advisors, and addresses_boba_bar.
    @dev Anyone is allowed to trigger this as the mint target is the "Minter" contract itself and distribution targets are stored in the contract.
    """
    self._mint_available()
    self._distribute_balance()


@external
def set_addresses(
    _addresses_emission: address[1],
    _addresses_treasury: address[1],
    _addresses_team_members: address[4],
    _addresses_advisors: address[2],
    _addresses_boba_bar: address[1]
):
    """
    @notice Sets new distribution addresses.
    @dev All arrays of addresses have to be passed. If a address should stay the same it just needs to be passed again.
    @param _addresses_emission Address of the emissions distributor.
    @param _addresses_treasury Address of the Kōyō Finance treasury.
    @param _addresses_team_members Addresses of all team members.
    @param _addresses_advisors Addresses of the 2 participating advisors.
    @param _addresses_boba_bar Address of the BobaBAR or BobaDAO.
    """
    self.assert_is_owner(msg.sender)

    self.addresses_emission = _addresses_emission
    self.addresses_treasury = _addresses_treasury
    self.addresses_team_members = _addresses_team_members
    self.addresses_advisors = _addresses_advisors
    self.addresses_boba_bar = _addresses_boba_bar


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

