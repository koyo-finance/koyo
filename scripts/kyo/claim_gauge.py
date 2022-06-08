import time

from brownie import accounts, LiquidityGaugeV1, GaugeController


DEPLOYER = accounts.load('p7m')
REQUIRED_CONFIRMATIONS = 2

def _tx_params(gas_limit: int = None):
    return {
        "from": DEPLOYER,
        "required_confs": REQUIRED_CONFIRMATIONS,
        "gas_limit": gas_limit
    }


def main():
    gauge = LiquidityGaugeV1.at("0x24f47A11AEE5d1bF96C18dDA7bB0c0Ef248A8e71")
    gauge_controller = GaugeController.at("0xe8c8dbCcE7450B1100A5e416525B2F6C5F7eaDba")

    # print(gauge.user_checkpoint(DEPLOYER, _tx_params(gas_limit=5_000_000)))
    print("inflation_rate ", gauge.inflation_rate())
    print("working_balances[addr] ", gauge.working_balances(DEPLOYER))
    print("working_supply ", gauge.working_supply())
    print("integrate_fraction[addr] ", gauge.integrate_fraction(DEPLOYER))
    print("gauge_relative_weight (current time) ", gauge_controller.gauge_relative_weight(gauge))
    print("gauge_relative_weight (weeks time) ", gauge_controller.gauge_relative_weight(gauge, 1654799102))

    print("gauge_relative_weight (current time + 1h) ", gauge_controller.gauge_relative_weight(gauge, time.time() + 3600))
    print("gauge_relative_weight (current time + 2h) ", gauge_controller.gauge_relative_weight(gauge, time.time() + 3600 * 2))
    print("gauge_relative_weight (current time + 4h) ", gauge_controller.gauge_relative_weight(gauge, time.time() + 3600 * 4))
    print("gauge_relative_weight (current time + 8h) ", gauge_controller.gauge_relative_weight(gauge, time.time() + 3600 * 8))
    print("gauge_relative_weight (current time + 12h) ", gauge_controller.gauge_relative_weight(gauge, time.time() + 3600 * 12))
    print("gauge_relative_weight (current time + 16h) ", gauge_controller.gauge_relative_weight(gauge, time.time() + 3600 * 16))
