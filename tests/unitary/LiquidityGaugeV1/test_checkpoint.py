import brownie

YEAR = 86400 * 365


def test_user_checkpoint(accounts, three_gauges):
    three_gauges[0].user_checkpoint(accounts[1], {"from": accounts[1]})


def test_user_checkpoint_new_period(accounts, chain, three_gauges):
    three_gauges[0].user_checkpoint(accounts[1], {"from": accounts[1]})
    chain.sleep(int(YEAR * 1.1))
    three_gauges[0].user_checkpoint(accounts[1], {"from": accounts[1]})


def test_user_checkpoint_wrong_account(accounts, three_gauges):
    with brownie.reverts():
        three_gauges[0].user_checkpoint(accounts[2], {"from": accounts[1]})
