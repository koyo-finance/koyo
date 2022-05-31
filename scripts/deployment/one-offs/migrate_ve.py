import json
from .. import deployment_config as config

from brownie import (
    Koyo,
    Minter,
    SmartWalletWhitelist,
    VotingEscrow,
)


def main():
    deploy_part_one(config.tx_params, config.DEPLOYMENTS_JSON)


def deploy_part_one(_tx_params, deployments_json=None):
    with open(config.DEPLOYMENTS_JSON) as fp:
        deployments = json.load(fp)

    token = Koyo.at(deployments["Koyo"])
    old_voting_escrow = VotingEscrow.at(deployments["VotingEscrow"])
    minter = Minter.at(deployments["Minter"])
    smart_wallet_whitelist = SmartWalletWhitelist.at(
        deployments["SmartWalletWhitelist"]
    )

    voting_escrow = VotingEscrow.deploy(
        token,
        "Vote-escrowed KYO",
        "veKYO",
        "veKYO_1.1.0",
        _tx_params(5_000_000),
    )
    voting_escrow = VotingEscrow.at(voting_escrow.address)

    voting_escrow.commit_smart_wallet_checker(
        smart_wallet_whitelist, _tx_params(5_000_000)
    )
    voting_escrow.apply_smart_wallet_checker(_tx_params(5_000_000))

    old_voting_escrow.commit_next_ve_contract(voting_escrow, _tx_params(5_000_000))
    old_voting_escrow.apply_next_ve_contract(_tx_params(5_000_000))

    deployments = {
        "Koyo": token.address,
        "VotingEscrow": voting_escrow.address,
        "Minter": minter.address,
        "SmartWalletWhitelist": smart_wallet_whitelist.address,
    }

    if deployments_json is not None:
        with open(deployments_json, "w") as fp:
            json.dump(deployments, fp)
        print(f"Deployment addresses saved to {deployments_json}")
