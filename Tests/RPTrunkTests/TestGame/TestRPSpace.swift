import RPTrunk

public struct TestRPSpace: RPSpaceDictionary, Equatable {
    
    public typealias Stats = TestStats
    
    public struct TestPosition: Codable, Equatable {
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public var bodies: [RPBodyId: RPBody<Self>] = [:]
    public var teams: [RPTeamId: RPTeam<Self>] = [:]
    public var pendingGameMasterEvents: [RPEvent<TestRPSpace>] = []
    public var positions: [RPBodyId: TestPosition] = [:]

    public init() {}

    public func position(forBodyId id: RPBodyId) -> (x: Double, y: Double) {
        guard let position = positions[id] else { return (0, 0) }
        return (position.x, position.y)
    }

    public func shouldCheckBodyIsValidTarget(_ id: RPBodyId, forOtherBodyId otherBodyId: RPBodyId) -> Bool {
        Self.shouldCheckRule?(id, otherBodyId) ?? true
    }

    public func willTargetBody(_ id: RPBodyId, forOtherBodyId otherBodyId: RPBodyId) -> Bool {
        Self.willTargetRule?(id, otherBodyId) ?? true
    }

    public static func fullyResolvedStats(for stats: TestStats) -> TestStats {
        stats
    }

    /// Test hook: lets individual tests define how events produce threat.
    nonisolated(unsafe) static var threatRule: ((RPEventResult<TestRPSpace>) -> [RPThreatChange])?

    nonisolated(unsafe) static var conflictRule: (
        (RPEvent<TestRPSpace>, TestRPSpace, RPBodyId, TestStats) -> RPConflictResult<TestRPSpace>
    )?

    nonisolated(unsafe) static var chanceRule: ((RPValue) -> Bool)?

    nonisolated(unsafe) static var additionalEventsRule: (
        (RPEventResult<TestRPSpace>, TestRPSpace) -> [RPEvent<TestRPSpace>]
    )?

    nonisolated(unsafe) static var shouldCheckRule: ((RPBodyId, RPBodyId) -> Bool)?

    nonisolated(unsafe) static var willTargetRule: ((RPBodyId, RPBodyId) -> Bool)?

    public static func resetTestHooks() {
        threatRule = nil
        conflictRule = nil
        chanceRule = nil
        additionalEventsRule = nil
        shouldCheckRule = nil
        willTargetRule = nil
    }

    public static func resolveThreatChanges(
        for eventResult: RPEventResult<TestRPSpace>,
        in rpSpace: TestRPSpace
    ) -> [RPThreatChange] {
        threatRule?(eventResult) ?? []
    }

    public static func rollTriggerChance(_ percent: RPValue) -> Bool {
        if let chanceRule {
            return chanceRule(percent)
        }
        return percent >= RPChance.certain
    }

    public static func additionalEvents(
        after result: RPEventResult<TestRPSpace>,
        in rpSpace: TestRPSpace
    ) -> [RPEvent<TestRPSpace>] {
        additionalEventsRule?(result, rpSpace) ?? []
    }

    public static func resolveConflict(_ event: RPEvent<Self>, in rpSpace: Self, target: RPBodyId, conflict: Stats) -> RPConflictResult<Self> {
        if let conflictRule {
            return conflictRule(event, rpSpace, target, conflict)
        }
        return RPConflictResult(bodyId: target, .zero)
        //    public func resolveConflict(
        //        _ event: RPEvent,
        //        in rpSpace: RPSpace,
        //        target: RPBodyId,
        //        conflict: Stats
        //    )  -> RPConflictResult {
        //
        //        guard let target = rpSpace.bodyById(target) else {
        //            return RPConflictResult(bodyId: target, [:])
        //        }
        //
        //        // hp result - part 1 - damage hits against hp, with defense as reduction
        //        var hpResult = 0 // + _b.affinities.healing
        //        hpResult -= (conflict["damage"] > 0) ? (conflict["damage"] - target["defense"]) : 0
        //
        //        let mpResult = 0 - conflict["mp"]
        //        // for reducing damage if the stat is below 0
        //        let dmgResult = (conflict["damage"] >= 0) ? 0 : conflict["damage"]
        //        // for reducing agility if the stat is below 0
        //        let agilityResult = conflict["agility"] >= 0 ? 0 : conflict["agility"]
        //        // for reducing defense if state is below 0
        //        let defenseResult = conflict["defense"] >= 0 ? 0 : conflict["defense"]
        //
        //        return RPConflictResult(target, [
        //            "hp": hpResult,
        //            "mp": mpResult,
        //            "damage": dmgResult,
        //            "agility": agilityResult,
        //            "magic": 0,
        //            "defense": defenseResult,
        //        ])
    }
}
