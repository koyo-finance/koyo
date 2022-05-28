import brownie


def test_commit_owner_only(koyo, accounts):
    with brownie.reverts("dev: owner only"):
        koyo.commit_transfer_ownership(accounts[1], {"from": accounts[1]})


def test_apply_owner_only(koyo, accounts):
    with brownie.reverts("dev: owner only"):
        koyo.apply_transfer_ownership({"from": accounts[1]})


def test_commit_transfer_ownership(koyo, accounts):
    koyo.commit_transfer_ownership(accounts[1], {"from": accounts[0]})

    assert koyo.owner() == accounts[0]
    assert koyo.future_owner() == accounts[1]


def test_apply_transfer_ownership(koyo, accounts):
    koyo.commit_transfer_ownership(accounts[1], {"from": accounts[0]})
    koyo.apply_transfer_ownership({"from": accounts[0]})

    assert koyo.owner() == accounts[1]

    koyo.commit_transfer_ownership(accounts[0], {"from": accounts[1]})
    koyo.apply_transfer_ownership({"from": accounts[1]})

    assert koyo.owner() == accounts[0]


def test_apply_without_commit(koyo, accounts):
    with brownie.reverts("dev: owner not set"):
        koyo.apply_transfer_ownership({"from": accounts[0]})
