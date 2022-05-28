import brownie


def test_set_minter_owner_only(koyo, accounts):
    with brownie.reverts("dev: owner only"):
        koyo.set_minter(accounts[1], {"from": accounts[1]})


def test_set_minter(koyo, accounts):
    koyo.set_minter(accounts[1], {"from": accounts[0]})

    assert koyo.minter() == accounts[1]

    koyo.set_minter(accounts[0], {"from": accounts[0]})

    assert koyo.minter() == accounts[0]


def test_mint_available_minter_only(koyo, accounts):
    with brownie.reverts("dev: minter only"):
        koyo.mint_available(accounts[1], {"from": accounts[1]})
