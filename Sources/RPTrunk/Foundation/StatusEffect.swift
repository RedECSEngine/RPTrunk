
public struct StatusEffect<RP: RPSpace>: Codable {
    public let name: String
    public let tags: [String]
    // both duration and charge can be used or one or the other
    let duration: RPTimeIncrement?
    let charges: Int? // the number of charges left
    let impairsAction: Bool
    let ability: Ability<RP>?

    public init(
        name: String,
        tags: [String],
        components: [Component<RP>],
        duration: Double?,
        charges: Int?,
        impairsAction: Bool = false
    ) {
        self.name = name
        self.tags = tags
        self.duration = duration
        self.charges = charges
        self.impairsAction = impairsAction

        if components.count > 0 {
            let components: [Component<RP>] = components + [Targeting<RP>(.oneself, .always).toComponent()]
            ability = Ability(name: name, components: components, cooldown: nil)
        } else {
            ability = nil
        }
    }

    public func getStatusEffects() -> [StatusEffect] {
        [self]
    }
}

extension StatusEffect: Equatable {}

public func ==<Stats: StatsType> (lhs: StatusEffect<Stats>, rhs: StatusEffect<Stats>) -> Bool {
    lhs.name == rhs.name
        && lhs.tags == rhs.tags
        && lhs.ability == rhs.ability
}
/**
    A Status effect, currently active on an entity
 */
public struct ActiveStatusEffect<RP: RPSpace>: Temporal, Codable {
    public var deltaTick: RPTimeIncrement = 0
    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement { statusEffect.duration ?? 0 }

    var currentCharge: Int = 0

    var level: Int? // power level of the buff, if it is stackable

    public var entityId: RPEntityId
    fileprivate let statusEffect: StatusEffect<RP>

    public var name: String { statusEffect.name }
    public var tags: [String] { statusEffect.tags }

    public init(
        entityId: RPEntityId,
        statusEffect: StatusEffect<RP>
    ) {
        self.entityId = entityId
        self.statusEffect = statusEffect
        currentCharge = statusEffect.charges ?? 0
    }

    public func shouldDisableEntity() -> Bool {
        statusEffect.impairsAction
    }

    public func getPendingEvents(in rpSpace: RP) -> [Event<RP>] {
        guard deltaTick > 1 else {
            return []
        }
        if let ability = statusEffect.ability {
            return [Event(category: .periodicEffect(name: name), initiator: entityId, ability: ability, rpSpace: rpSpace)]
        }
        return []
    }

    public mutating func tick(_ moment: Moment) {
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
