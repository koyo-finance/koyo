from brownie import accounts


DEPLOYMENTS_JSON = "deployments.json"
REQUIRED_CONFIRMATIONS = 2


def get_live_admin():
    admin = accounts.load('p7m')
    return admin


def tx_params(gas_limit: int = None):
    return {
        "from": get_live_admin(),
        "required_confs": REQUIRED_CONFIRMATIONS,
        "gas_limit": gas_limit
    }
