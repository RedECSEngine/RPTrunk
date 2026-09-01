public struct RPAbility<RP: RPSpace>: RPFragmentContainer, Codable {
    public var code: RPReferenceCode
    public var displayName: String
    public var tags: Set<RPAbilityTag> = []
    public var fragments: [RPFragment<RP>]
    public var cooldown: RPTimeIncrement
    public var executionRange: Double?
    public var repeats: Int = 1
    public var subAbilities: [RPAbility<RP>] = []
    public var metadata: RP.AbilityMetadata?

    public init(
        code: RPReferenceCode,
        displayName: String? = nil,
        tags: Set<RPAbilityTag> = [],
        fragments: [RPFragment<RP>] = [],
        cooldown: RPTimeIncrement? = nil
    ) {
        self.code = code
        self.displayName = displayName ?? code
        self.tags = tags
        self.fragments = fragments
        self.cooldown = cooldown ?? 0
    }
}

extension RPAbility: Equatable {}
public func == <RP: RPSpace>(lhs: RPAbility<RP>, rhs: RPAbility<RP>) -> Bool {
    lhs.code == rhs.code && lhs.isEqualTo(rhs)
}

/**
    An ability, currently active on an body
 */
public struct RPActiveAbility<RP: RPSpace>: RPTemporal, Codable {
    public typealias Stats = RP.Stats
    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement { ability.cooldown }

    public var bodyId: RPBodyId
    public let ability: RPAbility<RP>
    public let conditional: RPConditional<RP>

    public init(bodyId: RPBodyId, ability: RPAbility<RP>, conditional: RPConditional<RP>) {
        self.bodyId = bodyId
        self.ability = ability
        self.conditional = conditional
        currentTick = ability.cooldown
    }

    public func isCoolingDown() -> Bool {
        currentTick < maximumTick
    }

    public func canExecute(in rpSpace: RP) -> Bool {
        guard isCoolingDown() == false else {
            return false
        }
        return wouldExecute(in: rpSpace)
    }

    public func wouldExecute(in rpSpace: RP) -> Bool {
        guard let body = rpSpace.bodyById(bodyId) else {
            return false
        }

        let statsCost = ability.statsCost
        guard statsCost == .zero || body.currentStats >= statsCost else {
            return false
        }

        let requiredStats = ability.requiredStats
        guard requiredStats == .zero || body.currentStats >= requiredStats else {
            return false
        }

        guard ability.requiredStatuses.allSatisfy({ $0.isSatisfied(by: body) }) else {
            return false
        }

        if let threatRequirement = ability.threatRequirement,
           !threatRequirement.isSatisfied(against: bodyId, in: rpSpace) {
            return false
        }

        return (try? conditional.exec(body, rpSpace: rpSpace)) ?? false
    }

    public func getPendingEvents(in rpSpace: RP) -> [RPEvent<RP>] {
        guard isCoolingDown() == false else {
            return []
        }
        return createEvents(in: rpSpace)
    }

    public func predictEvents(in rpSpace: RP) -> [RPEvent<RP>] {
        createEvents(in: rpSpace)
    }

    fileprivate func createEvents(in rpSpace: RP) -> [RPEvent<RP>] {
        (0 ..< ability.repeats).map { _ in RPEvent<RP>(initiator: bodyId, ability: ability, rpSpace: rpSpace) }
    }

    public mutating func tick(_ moment: RPMoment) {
        if isCoolingDown() {
            currentTick += moment.delta
        }
    }

    public mutating func resetCooldown() {
        currentTick = 0
    }

    //TODO: revisit this function, was made pre-value type conversion
    public func copyForBody(_ body: RPBody<RP>) -> RPActiveAbility {
        RPActiveAbility(bodyId: body.id, ability: ability, conditional: conditional)
    }
}
