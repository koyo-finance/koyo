import json
from .. import deployment_config as config

from brownie import (
    Koyo,
    GaugeDistributor,
    VotingEscrow,
    GaugeController,
    LiquidityGaugeV1,
)


# lp token, gauge weight
POOL_TOKENS = {
    "KYO-ETH": ("0xf425eD6a3d48bf765853c8cD3Bf4B697af8D3B04", 1000),
    "FETH": ("0x5EC75124616Dc136dEa5560A59512404a133209b", 500),
}


def main():
    deploy_part_one(config.tx_params, config.DEPLOYMENTS_JSON)


def deploy_part_one(_tx_params, deployments_json=None):
    with open(config.DEPLOYMENTS_JSON) as fp:
        deployments = json.load(fp)

    token = Koyo.at(deployments["Koyo"])
    voting_escrow = VotingEscrow.at(deployments["VotingEscrow"])
    gauge_controller = GaugeController.at(deployments["GaugeController"])
    gauge_distributor = GaugeDistributor.at(deployments["GaugeDistributor"])

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
