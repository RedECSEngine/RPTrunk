
public struct RPStatusEffect<RP: RPSpace>: Codable {
    /// Default time between pulses (ms) when a status effect doesn't specify one.
    public static var defaultPeriod: RPTimeIncrement { 1000 }

    public let code: RPReferenceCode
    public let displayName: String
    public let tags: [String]
    // both duration and charge can be used or one or the other
    let duration: RPTimeIncrement?
    let charges: Int? // the number of charges left
    let impairsAction: Bool
    /// Time (ms) between periodic pulses of this effect (heal/damage over time).
    let period: RPTimeIncrement
    let ability: RPAbility<RP>?

    public init(
        code: RPReferenceCode,
        displayName: String? = nil,
        tags: [String],
        components: [Component<RP>],
        duration: Double?,
        charges: Int?,
        impairsAction: Bool = false,
        period: RPTimeIncrement = RPStatusEffect.defaultPeriod
    ) {
        self.code = code
        self.displayName = displayName ?? code
        self.tags = tags
        self.duration = duration
        self.charges = charges
        self.impairsAction = impairsAction
        self.period = period

        if components.count > 0 {
            let components: [Component<RP>] = components + [RPTargeting<RP>(.oneself, .always).toComponent()]
            ability = RPAbility(code: code, displayName: displayName, components: components, cooldown: nil)
        } else {
            ability = nil
        }
    }

    public func getStatusEffects() -> [RPStatusEffect] {
        [self]
    }
}

extension RPStatusEffect: Equatable {}

public func ==<Stats: StatsType> (lhs: RPStatusEffect<Stats>, rhs: RPStatusEffect<Stats>) -> Bool {
    lhs.code == rhs.code
        && lhs.tags == rhs.tags
        && lhs.ability == rhs.ability
}
/**
    A Status effect, currently active on an entity
 */
public struct RPActiveStatusEffect<RP: RPSpace>: Temporal, Codable {
    public var deltaTick: RPTimeIncrement = 0
    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement { statusEffect.duration ?? 0 }

    var currentCharge: Int = 0

    var level: Int? // power level of the buff, if it is stackable

    public var entityId: RPEntityId
    fileprivate let statusEffect: RPStatusEffect<RP>

    public var code: RPReferenceCode { statusEffect.code }
    public var displayName: String { statusEffect.displayName }
    public var tags: [String] { statusEffect.tags }

    public init(
        entityId: RPEntityId,
        statusEffect: RPStatusEffect<RP>
    ) {
        self.entityId = entityId
        self.statusEffect = statusEffect
        currentCharge = statusEffect.charges ?? 0
    }

    public func shouldDisableEntity() -> Bool {
        statusEffect.impairsAction
    }

    public func getPendingEvents(in rpSpace: RP) -> [RPEvent<RP>] {
        // Pulse once the accumulated time reaches the effect's configured period.
        guard deltaTick >= statusEffect.period else {
            return []
        }
        if let ability = statusEffect.ability {
            return [RPEvent(category: .periodicEffect(name: code), initiator: entityId, ability: ability, rpSpace: rpSpace)]
        }
        return []
    }

    public mutating func tick(_ moment: RPMoment) {
        guard isCoolingDown() else {
            return
        }

        deltaTick += moment.delta
    }

    public mutating func incrementTick() {
        deltaTick = 0
        currentTick += 1
    }

    public mutating func resetCooldown() {
        currentTick = 0
    }

    public mutating func expendCharge() {
        currentCharge -= 1
        if currentCharge <= 0 {
            currentTick = maximumTick
        }
    }

    public func isCoolingDown() -> Bool {
        guard statusEffect.duration != nil else {
            return false
        }
        return currentTick < maximumTick
    }
}
