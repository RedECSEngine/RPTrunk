@testable import RPTrunk
import XCTest

final class TargetingLanguageTests: XCTestCase {

    typealias Targeting = RPTargeting<TestRPSpace>

    func testRoundTripsCanonicalStrings() throws {
        let strings = [
            "pick: enemy sort: threat.highest",
            "pick: friendly when: hp% < 100% sort: hp%.lowest",
            "pick: self when: hp < 1 && !has.ko",
            "pick: friendly when: has.poison sort: hp.lowest",
            "pick: friendly sort: any",
            "pick: all sort: random",
            "pick: initiator",
            "pick: allyTeam",
            "pick: friendly when: self.hp% < hp%",
            "pick: friendly when: uses.magical sort: hp%.lowest, threat.highest",
        ]
        for string in strings {
            let parsed = try Targeting.fromString(string)
            XCTAssertEqual(parsed.toString(), string)
            XCTAssertEqual(try Targeting.fromString(parsed.toString()), parsed)
        }
    }

    func testParsingRejectsMalformedStrings() {
        XCTAssertThrowsError(try Targeting.fromString("singleFriendly:hp% < 100%"))
        XCTAssertThrowsError(try Targeting.fromString("pick: sideways"))
        XCTAssertThrowsError(try Targeting.fromString("pick: enemy pick: friendly"))
        XCTAssertThrowsError(try Targeting.fromString("pick: enemy, when: hp < 1"))
        XCTAssertThrowsError(try Targeting.fromString("pick: enemy foo: bar"))
        XCTAssertThrowsError(try Targeting.fromString("pick: enemy sort: hp%.sideways"))
        XCTAssertThrowsError(try Targeting.fromString("pick: enemy sort: random, hp%.lowest"))
    }

    func testEveryClauseIsOptional() throws {
        XCTAssertEqual(try Targeting.fromString(""), Targeting(.all))
        XCTAssertEqual(try Targeting.fromString("  "), Targeting(.all))
        XCTAssertEqual(
            try Targeting.fromString("when: hp < 1"),
            Targeting(.all, "hp < 1")
        )
        XCTAssertEqual(
            try Targeting.fromString("sort: hp%.lowest"),
            Targeting(.all, sort: try RPTargetingSort.parse("hp%.lowest"))
        )
        XCTAssertEqual(try Targeting.fromString("pick: friendly"), Targeting(.friendly))
    }

    private func makeTeam(hp: [String: RPValue]) -> TestRPSpace {
        var space = TestRPSpace()
        var team = RPTeam<TestRPSpace>()
        var bodies: [RPBody<TestRPSpace>] = []
        for (id, currentHP) in hp {
            var body = RPBody<TestRPSpace>(["hp": 10])
            body.id = id
            team.add(&body)
            body.setCurrentStats(.init(dict: ["hp": currentHP]))
            body.targets = Set(hp.keys)
            bodies.append(body)
        }
        bodies.forEach { space.addBody($0) }
        space.setTeams([team])
        return space
    }

    func testChooseLowestHPPercentPicksTheMostWounded() throws {
        let space = makeTeam(hp: ["healer": 10, "ally-scratched": 8, "ally-hurt": 3])
        let targeting = try Targeting.fromString("pick: friendly when: hp% < 100% sort: hp%.lowest")
        XCTAssertEqual(targeting.getValidTargets(for: "healer", in: space), ["ally-hurt"])
    }

    func testChooseFallsThroughEqualValuesToTheIdTiebreak() throws {
        let space = makeTeam(hp: ["healer": 10, "b-ally": 4, "a-ally": 4])
        let targeting = try Targeting.fromString("pick: friendly sort: hp.lowest")
        XCTAssertEqual(targeting.getValidTargets(for: "healer", in: space), ["a-ally"])
    }

    func testMultipleDescriptorsFormATiebreakChain() throws {
        var space = makeTeam(hp: ["healer": 10, "b-ally": 4, "a-ally": 4])
        space.modifyBody(id: "healer") { body, _ in
            body.addThreat(toward: "b-ally", amount: 5)
        }
        let targeting = try Targeting.fromString("pick: friendly sort: hp.lowest, threat.highest")
        XCTAssertEqual(targeting.getValidTargets(for: "healer", in: space), ["b-ally"])
    }

    func testAbsentChooseReturnsTheWholeFilteredPool() throws {
        let space = makeTeam(hp: ["healer": 10, "ally-scratched": 8, "ally-hurt": 3])
        let targeting = try Targeting.fromString("pick: friendly when: hp% < 100%")
        XCTAssertEqual(targeting.getValidTargets(for: "healer", in: space), ["ally-scratched", "ally-hurt"])
    }

    func testDefaultTargetingStillPicksHighestThreat() {
        var space = TestRPSpace()
        var attackers = RPTeam<TestRPSpace>()
        var defenders = RPTeam<TestRPSpace>()
        var hero = RPBody<TestRPSpace>(["hp": 10])
        hero.id = "hero"
        var foeA = RPBody<TestRPSpace>(["hp": 10])
        foeA.id = "foe-a"
        var foeB = RPBody<TestRPSpace>(["hp": 10])
        foeB.id = "foe-b"
        attackers.add(&hero)
        defenders.add(&foeA)
        defenders.add(&foeB)
        attackers.enemies = [defenders.id]
        defenders.enemies = [attackers.id]
        hero.targets = ["foe-a", "foe-b"]
        hero.addThreat(toward: "foe-b", amount: 50)
        space.addBody(hero)
        space.addBody(foeA)
        space.addBody(foeB)
        space.setTeams([attackers, defenders])

        let targeting = RPTargeting<TestRPSpace>(.enemy, sort: .highestThreat)
        XCTAssertEqual(targeting.getValidTargets(for: "hero", in: space), ["foe-b"])
    }

    func testChooseRandomOnAnEmptyPoolIsEmptyNotACrash() throws {
        var space = TestRPSpace()
        var team = RPTeam<TestRPSpace>()
        var loner = RPBody<TestRPSpace>(["hp": 10])
        loner.id = "loner"
        team.add(&loner)
        space.addBody(loner)
        space.setTeams([team])

        let targeting = try Targeting.fromString("pick: friendly when: hp < 0 sort: random")
        XCTAssertEqual(targeting.getValidTargets(for: "loner", in: space), [])
    }

    func testChooseRandomPicksExactlyOneCandidate() throws {
        let space = makeTeam(hp: ["healer": 10, "ally-a": 10, "ally-b": 10])
        let targeting = try Targeting.fromString("pick: friendly sort: random")
        let targets = targeting.getValidTargets(for: "healer", in: space)
        XCTAssertEqual(targets.count, 1)
    }

    func testSelfPrefixComparesInitiatorAgainstCandidate() throws {
        let space = makeTeam(hp: ["healer": 3, "ally-strong": 8, "ally-weak": 1])
        let targeting = try Targeting.fromString("pick: friendly when: hp < self.hp")
        XCTAssertEqual(targeting.getValidTargets(for: "healer", in: space), ["ally-weak"])
    }

    func testHasPrefixFiltersByStatusTag() throws {
        var space = makeTeam(hp: ["healer": 10, "ally-clean": 10, "ally-poisoned": 10])
        space.modifyBody(id: "ally-poisoned") { body, _ in
            body.applyStatusEffect(RPStatusEffect<TestRPSpace>(
                code: "Poison",
                tags: ["poison"],
                duration: 10000,
                charges: nil
            ))
        }
        let targeting = try Targeting.fromString("pick: friendly when: has.poison sort: hp.lowest")
        XCTAssertEqual(targeting.getValidTargets(for: "healer", in: space), ["ally-poisoned"])
    }

    func testUsesPrefixQueriesExecutableAbilityTags() throws {
        var space = makeTeam(hp: ["healer": 10, "ally-caster": 10, "ally-brute": 10])
        space.modifyBody(id: "ally-caster") { body, _ in
            body.addExecutableAbility(
                RPAbility<TestRPSpace>(code: "Zap", tags: [RPAbilityTag("magical")]),
                conditional: .always
            )
        }
        let targeting = try Targeting.fromString("pick: friendly when: uses.magical")
        XCTAssertEqual(targeting.getValidTargets(for: "healer", in: space), ["ally-caster"])
    }
}
