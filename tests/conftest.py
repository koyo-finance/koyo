import pytest


@pytest.fixture(scope="session")
def alice(accounts):
    yield accounts[0]


@pytest.fixture(scope="session")
def bob(accounts):
    yield accounts[1]


# region Minter - accounts
@pytest.fixture(scope="session")
def minter_initial_emissions(accounts):
    yield [accounts[2]]


@pytest.fixture(scope="session")
def minter_initial_treasury(accounts):
    yield [accounts[3]]


@pytest.fixture(scope="session")
def minter_initial_team_members(accounts):
    yield accounts[4:8]


@pytest.fixture(scope="session")
def minter_initial_advisors(accounts):
    yield accounts[8:10]


@pytest.fixture(scope="session")
def minter_initial_boba_bar(accounts):
    yield [accounts[10]]


# endregion Minter - accounts


@pytest.fixture(scope="module")
def smart_wallet_whitelist(SmartWalletWhitelist, accounts):
    yield SmartWalletWhitelist.deploy({"from": accounts[0]})


@pytest.fixture(scope="module")
def koyo(Koyo, accounts):
    yield Koyo.deploy("Kōyō Token", "KYO", 18, {"from": accounts[0]})


@pytest.fixture(scope="module")
def voting_escrow(VotingEscrow, accounts, koyo):
    yield VotingEscrow.deploy(
        koyo, "Voting-escrowed KYO", "veKYO", "veKOYO_1", {"from": accounts[0]}
    )


@pytest.fixture(scope="module")
def mock_lp_token(ERC20LP, accounts):
    yield ERC20LP.deploy("Koyo LP token", "usdKYO", 18, 10**9, {"from": accounts[0]})


@pytest.fixture(scope="module")
def minter(
    Minter,
    koyo,
    minter_initial_emissions,
    minter_initial_treasury,
    minter_initial_team_members,
    minter_initial_advisors,
    minter_initial_boba_bar,
    accounts,
):
    yield Minter.deploy(
        koyo,
        minter_initial_emissions,
        minter_initial_treasury,
        minter_initial_team_members,
        minter_initial_advisors,
        minter_initial_boba_bar,
        {"from": accounts[0]},
    )


@pytest.fixture(scope="module")
def gauge_controller(
    GaugeController,
    koyo,
    voting_escrow,
    accounts,
):
    yield GaugeController.deploy(
        koyo,
        voting_escrow,
        {"from": accounts[0]},
    )


@pytest.fixture(scope="module")
def gauge_distributor(
    GaugeDistributor,
    koyo,
    minter,
    gauge_controller,
    accounts,
):
    yield GaugeDistributor.deploy(
        koyo,
        minter,
        gauge_controller,
        {"from": accounts[0]},
    )


@pytest.fixture(scope="module")
def three_gauges(
    LiquidityGaugeV1,
    koyo,
    voting_escrow,
    gauge_distributor,
    gauge_controller,
    mock_lp_token,
    accounts,
):
    contracts = [
        LiquidityGaugeV1.deploy(
            koyo,
            voting_escrow,
            gauge_distributor,
            gauge_controller,
            mock_lp_token,
            accounts[0],
            {"from": accounts[0]},
        )
        for _ in range(3)
    ]

    yield contracts


def approx(a, b, precision=1e-10):
    if a == b == 0:
        return True
    return 2 * abs(a - b) / (a + b) <= precision
