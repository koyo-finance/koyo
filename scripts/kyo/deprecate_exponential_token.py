from brownie import accounts, Koyo


DEPLOYER = accounts.load('p7m')
REQUIRED_CONFIRMATIONS = 2


def _tx_params(gas_limit: int = None):
    return {
        "from": DEPLOYER,
        "required_confs": REQUIRED_CONFIRMATIONS,
        "gas_limit": gas_limit
    }


def main():
    koyo = Koyo.at("0x2F11899C848Ac0251D1F168cB658a44Eef97F2EA")

    koyo.set_name("DEAD - Kōyō Token - Expontial", "D-KYO-E", _tx_params(5_000_000))
