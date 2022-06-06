import pytest


@pytest.mark.parametrize("idx", range(5))
def test_initial_approval_is_zero(three_gauges, accounts, idx):
    assert three_gauges[0].allowance(accounts[0], accounts[idx]) == 0


def test_approve(three_gauges, accounts):
    three_gauges[0].approve(accounts[1], 10 ** 19, {"from": accounts[0]})

    assert three_gauges[0].allowance(accounts[0], accounts[1]) == 10 ** 19


def test_modify_approve(three_gauges, accounts):
    three_gauges[0].approve(accounts[1], 10 ** 19, {"from": accounts[0]})
    three_gauges[0].approve(accounts[1], 12345678, {"from": accounts[0]})

    assert three_gauges[0].allowance(accounts[0], accounts[1]) == 12345678


def test_revoke_approve(three_gauges, accounts):
    three_gauges[0].approve(accounts[1], 10 ** 19, {"from": accounts[0]})
    three_gauges[0].approve(accounts[1], 0, {"from": accounts[0]})

    assert three_gauges[0].allowance(accounts[0], accounts[1]) == 0


def test_approve_self(three_gauges, accounts):
    three_gauges[0].approve(accounts[0], 10 ** 19, {"from": accounts[0]})

    assert three_gauges[0].allowance(accounts[0], accounts[0]) == 10 ** 19


def test_only_affects_target(three_gauges, accounts):
    three_gauges[0].approve(accounts[1], 10 ** 19, {"from": accounts[0]})

    assert three_gauges[0].allowance(accounts[1], accounts[0]) == 0


def test_returns_true(three_gauges, accounts):
    tx = three_gauges[0].approve(accounts[1], 10 ** 19, {"from": accounts[0]})

    assert tx.return_value is True


def test_approval_event_fires(accounts, three_gauges):
    tx = three_gauges[0].approve(accounts[1], 10 ** 19, {"from": accounts[0]})

    assert len(tx.events) == 1
    assert tx.events["Approval"].values() == [accounts[0], accounts[1], 10 ** 19]


def test_increase_allowance(accounts, three_gauges):
    three_gauges[0].approve(accounts[1], 100, {"from": accounts[0]})
    three_gauges[0].increaseAllowance(accounts[1], 403, {"from": accounts[0]})

    assert three_gauges[0].allowance(accounts[0], accounts[1]) == 503


def test_decrease_allowance(accounts, three_gauges):
    three_gauges[0].approve(accounts[1], 100, {"from": accounts[0]})
    three_gauges[0].decreaseAllowance(accounts[1], 34, {"from": accounts[0]})

    assert three_gauges[0].allowance(accounts[0], accounts[1]) == 66
