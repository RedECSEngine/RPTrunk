
public struct StatusEffect: Codable {
    public let name: String
    public let labels: [String]
    // both duration and charge can be used or one or the other
    let duration: RPTimeIncrement?
    let charges: Int? // the number of charges left
    let impairsAction: Bool
    let ability: Ability?

    public init(
        name: String,
        labels: [String],
        components: [Component],
        duration: Double?,
        charges: Int?,
        impairsAction: Bool = false
    ) {
        self.name = name
        self.labels = labels
        self.duration = duration
        self.charges = charges
        self.impairsAction = impairsAction

        if components.count > 0 {
            let components: [Component] = components + [Targeting(.oneself, .always).toComponent()]
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

public func == (lhs: StatusEffect, rhs: StatusEffect) -> Bool {
    lhs.name == rhs.name
        && lhs.labels == rhs.labels
        && lhs.ability == rhs.ability
}

public struct ActiveStatusEffect: Temporal, Codable {
    fileprivate var deltaTick: RPTimeIncrement = 0
    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement { statusEffect.duration ?? 0 }

    var currentCharge: Int = 0

    var level: Int? // power level of the buff, if it is stackable

    public var entityId: String
    fileprivate let statusEffect: StatusEffect

    public var name: String { statusEffect.name }
    public var labels: [String] { statusEffect.labels }

    public init(
        entityId: String,
        statusEffect: StatusEffect
    ) {
        self.entityId = entityId
        self.statusEffect = statusEffect
        currentCharge = statusEffect.charges ?? 0
    }

    public func shouldDisableEntity() -> Bool {
        statusEffect.impairsAction
    }

    public func getPendingEvents(in rpSpace: RPSpace) -> [Event] {
        guard deltaTick > 1 else {
            return []
        }
        if let entity = rpSpace.entities[entityId],
           let ability = statusEffect.ability
        {
            return [Event(category: .periodicEffect, initiator: entity, ability: ability, rpSpace: rpSpace)]
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
        if statusEffect.duration != nil {
            return currentTick < maximumTick
        } else {
            return currentCharge != 0
        }
    }
}
