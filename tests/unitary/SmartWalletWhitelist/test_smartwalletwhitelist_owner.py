import brownie


def test_commit_owner_only(smart_wallet_whitelist, accounts):
    with brownie.reverts("dev: owner only"):
        smart_wallet_whitelist.commit_transfer_ownership(accounts[1], {"from": accounts[1]})


def test_apply_owner_only(smart_wallet_whitelist, accounts):
    with brownie.reverts("dev: owner only"):
        smart_wallet_whitelist.apply_transfer_ownership({"from": accounts[1]})


def test_commit_transfer_ownership(smart_wallet_whitelist, accounts):
    smart_wallet_whitelist.commit_transfer_ownership(accounts[1], {"from": accounts[0]})

    assert smart_wallet_whitelist.owner() == accounts[0]
    assert smart_wallet_whitelist.future_owner() == accounts[1]


def test_apply_transfer_ownership(smart_wallet_whitelist, accounts):
    smart_wallet_whitelist.commit_transfer_ownership(accounts[1], {"from": accounts[0]})
    smart_wallet_whitelist.apply_transfer_ownership({"from": accounts[0]})

    assert smart_wallet_whitelist.owner() == accounts[1]

    smart_wallet_whitelist.commit_transfer_ownership(accounts[0], {"from": accounts[1]})
    smart_wallet_whitelist.apply_transfer_ownership({"from": accounts[1]})

    assert smart_wallet_whitelist.owner() == accounts[0]


def test_apply_without_commit(smart_wallet_whitelist, accounts):
    with brownie.reverts("dev: owner not set"):
        smart_wallet_whitelist.apply_transfer_ownership({"from": accounts[0]})
