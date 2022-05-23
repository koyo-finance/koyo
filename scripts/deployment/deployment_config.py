from brownie import accounts


DEPLOYMENTS_JSON = "deployments.json"
REQUIRED_CONFIRMATIONS = 1


def get_live_admin():
    admin = accounts.load('p7m')
    return admin


def _tx_params(admin = get_live_admin(), gas_limit: int = None):
    return {
        "from": admin,
        "required_confs": REQUIRED_CONFIRMATIONS,
        "gas_limit": gas_limit
    }
