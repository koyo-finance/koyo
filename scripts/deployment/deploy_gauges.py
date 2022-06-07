import json
from . import deployment_config as config

from brownie import (
    Koyo,
    Minter,
    GaugeDistributor,
    VotingEscrow,
    GaugeController,
    LiquidityGaugeV1,
)


GAUGE_TYPES = [
    ("Liquidity", 10**18),
]

# lp token, gauge weight
POOL_TOKENS = {
    "4Koyo": ("0x9F0a572be1Fcfe96E94C0a730C5F4bc2993fe3F6", 100),
}


def main():
    deploy_part_one(config.tx_params, config.DEPLOYMENTS_JSON)


def deploy_part_one(_tx_params, deployments_json=None):
    with open(config.DEPLOYMENTS_JSON) as fp:
        deployments = json.load(fp)

    token = Koyo.at(deployments["Koyo"])
    minter = Minter.at(deployments["Minter"])
    voting_escrow = VotingEscrow.at(deployments["VotingEscrow"])

    gauge_controller = GaugeController.deploy(
        token, voting_escrow, _tx_params(gas_limit=5_000_000)
    )
    gauge_distributor = GaugeDistributor.deploy(
        token, minter, gauge_controller, _tx_params(gas_limit=5_000_000)
    )

    deployments["GaugeController"] = gauge_controller.address
    deployments["GaugeDistributor"] = gauge_distributor.address

    for name, weight in GAUGE_TYPES:
        gauge_controller.add_type(name, weight, _tx_params(gas_limit=5_000_000))

    deployments["Gauge"] = {}

    for name, (lp_token, weight) in POOL_TOKENS.items():
        gauge = LiquidityGaugeV1.deploy(
            token,
            voting_escrow,
            gauge_distributor,
            gauge_controller,
            lp_token,
            _tx_params(gas_limit=5_000_000),
        )
        gauge_controller.add_gauge(gauge, 0, weight, _tx_params(gas_limit=5_000_000))
        deployments["Gauge"][name] = gauge.address

    if deployments_json is not None:
        with open(deployments_json, "w") as fp:
            json.dump(deployments, fp)
        print(f"Deployment addresses saved to {deployments_json}")
