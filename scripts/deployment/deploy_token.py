import json
from . import deployment_config as config

from brownie import (
    Koyo,
    Minter,
    SmartWalletWhitelist,
    VotingEscrow,
)


ADDRESSES_EMISSION = []  # 1
ADDRESSES_TREASURY = ["0x559dBda9Eb1E02c0235E245D9B175eb8DcC08398"]  # 1
ADDRESSES_TEAM_MEMBERS = [
    "0xC4d54E7e94B68d88Ad7b00d0689669d520cce2fB",  # p7m
    "0xC983Ebc9dB969782D994627bdfFeC0ae6efee1b3",  # eD
    "0xbb6cBCa48EF0e6AD1110AAf866eeF4410252BD5B",  # BR
    "0x0ad4f3762E14E6183E7b67f37C3DF53FAbfCa532"  # Zibro
]  # 4
ADDRESSES_ADVISORS = [
    "0x9D097697e5B82a52f6b82c16c148a753bBF5C8ae",  # G
    "0x03b007DD9C84153C233CD2A5f6bf7A6242f9E291",  # M
]  # 2
ADDRESSES_BOBA_BAR = []  # 1


def live_part_one():
    deploy_part_one(config.tx_params, config.DEPLOYMENTS_JSON)


def live_part_two():
    with open(config.DEPLOYMENTS_JSON) as fp:
        deployments = json.load(fp)

    token = Koyo.at(deployments["Koyo"])
    voting_escrow = VotingEscrow.at(deployments["VotingEscrow"])

    deploy_part_two(token, voting_escrow, config.tx_params, config.DEPLOYMENTS_JSON)


def deploy_part_one(_tx_params, deployments_json=None):
    token = Koyo.deploy("Koyo Token", "KYO", 18, _tx_params(5_000_000))
    voting_escrow = VotingEscrow.deploy(
        token,
        "Vote-escrowed KYO",
        "veKYO",
        "veKYO_1.0.0",
        _tx_params(5_000_000),
    )

    deployments = {
        "Koyo": token.contract_address,
        "VotingEscrow": voting_escrow.contract_address,
    }

    if deployments_json is not None:
        with open(deployments_json, "w") as fp:
            json.dump(deployments, fp)
        print(f"Deployment addresses saved to {deployments_json}")

    return token, voting_escrow


def deploy_part_two(token, voting_escrow, _tx_params, deployments_json=None):
    smart_wallet_whitelist = SmartWalletWhitelist.deploy(_tx_params(5_000_000))
    minter = Minter.deploy(
        token,
        ADDRESSES_EMISSION,
        ADDRESSES_TREASURY,
        ADDRESSES_TEAM_MEMBERS,
        ADDRESSES_ADVISORS,
        ADDRESSES_BOBA_BAR,
        _tx_params(5_000_000),
    )

    token.set_minter(minter, _tx_params(5_000_000))

    voting_escrow.commit_smart_wallet_checker(
        smart_wallet_whitelist, _tx_params(5_000_000)
    )
    voting_escrow.apply_smart_wallet_checker(_tx_params(5_000_000))

    deployments = {
        "Koyo": token.contract_address,
        "VotingEscrow": voting_escrow.contract_address,
        "Minter": minter.contract_address,
        "SmartWalletWhitelist": smart_wallet_whitelist.contract_address,
    }

    if deployments_json is not None:
        with open(deployments_json, "w") as fp:
            json.dump(deployments, fp)
        print(f"Deployment addresses saved to {deployments_json}")
