import Foundation

public struct RPItem<RP: RPSpace>: Temporal, ComponentContainer, Codable, Equatable {
    public var id: RPItemId = UUID().uuidString
    public var name: String
    public var amount: Int = 1

    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement { ability?.cooldown ?? 0 }

    public var entity: RPEntityId?
    public var components: [Component<RP>]
    public var ability: Ability<RP>?
    public var conditional: Conditional<RP>

    public init(
        components: [Component<RP>] = [],
        ability: Ability<RP>? = nil,
        conditional: Conditional<RP> = .always
    ) {
        name = "Untitled Item"
        self.components = components
        self.ability = ability
        self.conditional = conditional
    }

    public func canExecute(in rpSpace: RP) -> Bool {
        guard isCoolingDown() == false else {
            return false
        }

        guard let entityId = entity,
              let e = rpSpace.entityById(entityId),
              let a = ability,
              a.cost < e.currentStats
        else {
            return false
        }

        return (try? conditional.exec(e, rpSpace: rpSpace)) ?? false
    }

    public func getPendingEvents(in rpSpace: RP) -> [Event<RP>] {
        guard isCoolingDown() == false else {
            return []
        }
        return createEvents(in: rpSpace)
    }

    fileprivate func createEvents(in rpSpace: RP) -> [Event<RP>] {
        guard let ability = self.ability,
              let entityId = self.entity
        else {
            return []
        }
        return (0 ..< ability.repeats).map { _ in
            Event(initiator: entityId, ability: ability, rpSpace: rpSpace)
        }
    }

    public mutating func tick(_ moment: Moment) {
        if isCoolingDown() {
            currentTick += moment.delta
        }
    }

    public mutating func resetCooldown() {
        currentTick = 0
    }
}
