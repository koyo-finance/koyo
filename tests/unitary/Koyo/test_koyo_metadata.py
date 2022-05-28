import brownie


def test_correct_metadata(koyo):
    assert koyo.name() == "Kōyō Token"
    assert koyo.symbol() == "KYO"

    assert koyo.decimals() == 18


def test_set_metadata_owner_only(koyo, accounts):
    with brownie.reverts("dev: owner only"):
        koyo.set_name("Kōyō", "KOYO", {"from": accounts[1]})


def test_set_metadata(koyo, accounts):
    koyo.set_name("Kōyō", "KOYO", {"from": accounts[0]})

    assert koyo.name() == "Kōyō"
    assert koyo.symbol() == "KOYO"

    koyo.set_name("Kōyō Token", "KYO", {"from": accounts[0]})

    assert koyo.name() == "Kōyō Token"
    assert koyo.symbol() == "KYO"

