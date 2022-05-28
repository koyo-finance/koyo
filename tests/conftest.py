import pytest


@pytest.fixture(scope="module")
def koyo(Koyo, accounts):
    yield Koyo.deploy("Koyo", "KYO", 18, {"from": accounts[0]})


@pytest.fixture(scope="module")
def voting_escrow(VotingEscrow, accounts, koyo):
    yield VotingEscrow.deploy(
        koyo, "Voting-escrowed KYO", "veKYO", "veKOYO_1", {"from": accounts[0]}
    )


def approx(a, b, precision=1e-10):
    if a == b == 0:
        return True
    return 2 * abs(a - b) / (a + b) <= precision
