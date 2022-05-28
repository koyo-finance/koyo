def test_switching_addresses(accounts, koyo, Minter):
    a0 = accounts[0]

    initial_emission = [accounts[2]]
    initial_treasury = [accounts[3]]
    initial_team_members = accounts[4:8]
    initial_advisors = accounts[8:10]
    initial_boba_bar = [accounts[10]]

    minter = Minter.deploy(koyo, initial_emission, initial_treasury, initial_team_members, initial_advisors, initial_boba_bar, {"from": a0})

    for ac in range(len(initial_emission)):
        assert minter.addresses_emission(ac) == initial_emission[ac]
    for ac in range(len(initial_treasury)):
        assert minter.addresses_treasury(ac) == initial_treasury[ac]
    for ac in range(len(initial_team_members)):
        assert minter.addresses_team_members(ac) == initial_team_members[ac]
    for ac in range(len(initial_advisors)):
        assert minter.addresses_advisors(ac) == initial_advisors[ac]
    for ac in range(len(initial_boba_bar)):
        assert minter.addresses_boba_bar(ac) == initial_boba_bar[ac]

    changed_emission = [accounts[11]]
    changed_treasury = [accounts[12]]
    changed_team_members = accounts[13:17]
    changed_advisors = accounts[17:19]
    changed_boba_bar = [accounts[19]]

    minter.set_addresses(changed_emission, changed_treasury, changed_team_members, changed_advisors, changed_boba_bar, {"from": a0})

    for ac in range(len(changed_emission)):
        assert minter.addresses_emission(ac) == changed_emission[ac]
    for ac in range(len(changed_treasury)):
        assert minter.addresses_treasury(ac) == changed_treasury[ac]
    for ac in range(len(changed_team_members)):
        assert minter.addresses_team_members(ac) == changed_team_members[ac]
    for ac in range(len(changed_advisors)):
        assert minter.addresses_advisors(ac) == changed_advisors[ac]
    for ac in range(len(changed_boba_bar)):
        assert minter.addresses_boba_bar(ac) == changed_boba_bar[ac]

    single_changed_emission = [accounts[20]]

    minter.set_addresses(single_changed_emission, changed_treasury, changed_team_members, changed_advisors, changed_boba_bar, {"from": a0})

    for ac in range(len(single_changed_emission)):
        assert minter.addresses_emission(ac) == single_changed_emission[ac]
    for ac in range(len(changed_treasury)):
        assert minter.addresses_treasury(ac) == changed_treasury[ac]
    for ac in range(len(changed_team_members)):
        assert minter.addresses_team_members(ac) == changed_team_members[ac]
    for ac in range(len(changed_advisors)):
        assert minter.addresses_advisors(ac) == changed_advisors[ac]
    for ac in range(len(changed_boba_bar)):
        assert minter.addresses_boba_bar(ac) == changed_boba_bar[ac]
