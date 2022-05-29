import json

from brownie import accounts, Minter


DEPLOYER = accounts.load("p7m")
REQUIRED_CONFIRMATIONS = 2

ADDRESSES_EMISSION = [
    "0xe61135368dC1e58fAa9EFb6FC384E78F5dfDaf74"  # Kōyō Finance - Emissions temporary vault
]  # 1
ADDRESSES_TREASURY = [
    "0x559dBda9Eb1E02c0235E245D9B175eb8DcC08398"  # Kōyō Finance - Treasury
]  # 1
ADDRESSES_TEAM_MEMBERS = [
    "0xC4d54E7e94B68d88Ad7b00d0689669d520cce2fB",  # p7m
    "0xC983Ebc9dB969782D994627bdfFeC0ae6efee1b3",  # eD
    "0xbb6cBCa48EF0e6AD1110AAf866eeF4410252BD5B",  # BR
    "0x0ad4f3762E14E6183E7b67f37C3DF53FAbfCa532",  # Zibro
]  # 4
ADDRESSES_ADVISORS = [
    "0x9D097697e5B82a52f6b82c16c148a753bBF5C8ae",  # G
    "0x03b007DD9C84153C233CD2A5f6bf7A6242f9E291",  # M
]  # 2
ADDRESSES_BOBA_BAR = [
    "0x05B0bFFfb9b7200083DD871f034A421330cD7398"  # BobaBAR multisig
]  # 1


def _tx_params(gas_limit: int = None):
    return {
        "from": DEPLOYER,
        "required_confs": REQUIRED_CONFIRMATIONS,
        "gas_limit": gas_limit,
    }


def main():
    with open("deployments.json") as fp:
        deployments = json.load(fp)

    minter = Minter.at(deployments["Minter"])

    minter.set_addresses(
        ADDRESSES_EMISSION,
        ADDRESSES_TREASURY,
        ADDRESSES_TEAM_MEMBERS,
        ADDRESSES_ADVISORS,
        ADDRESSES_BOBA_BAR,
        _tx_params(5_000_000),
    )
