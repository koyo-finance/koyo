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
    "4Koyo": ("0xDAb3Fc342A242AdD09504bea790f9b026Aa1e709", 100),
    "KYO-ETH": ("0xf425eD6a3d48bf765853c8cD3Bf4B697af8D3B04", 1000),
    "FETH": ("0x5EC75124616Dc136dEa5560A59512404a133209b", 500),
    "BOBA": ("0xF8DDdDa221F01db28fdb4D0849B4F8802c116ee6", 200),
    "FBP": ("0xe529b330017f3ee8b4665b0cae4b9c224e1dab38", 2000),
    "OLO-KYO<>wETH": ("0x0AdF26900b6088C2a5b3677F40ED9fc6913a9631", 2000),
    "2KYO-Stable": ("0xE8a2143598D841972513EEa37f632a233E93B2B9", 5000),
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
