import json

from brownie import accounts, Minter


DEPLOYER = accounts.load('p7m')
REQUIRED_CONFIRMATIONS = 2

def _tx_params(gas_limit: int = None):
    return {
        "from": DEPLOYER,
        "required_confs": REQUIRED_CONFIRMATIONS,
        "gas_limit": gas_limit
    }


def main():
    with open("deployments.json") as fp:
        deployments = json.load(fp)

    minter = Minter.at(deployments["Minter"])

    minter.mint_and_distribute(_tx_params(5_000_000))
