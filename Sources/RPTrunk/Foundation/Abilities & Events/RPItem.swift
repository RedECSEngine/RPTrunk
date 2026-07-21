public struct RPItem<RP: RPSpace>: ComponentContainer, Codable, Equatable {
    public var code: RPReferenceCode
    public var displayName: String
    public var maximumStack: Int?
    public var components: [Component<RP>]
    public var ability: Ability<RP>?
    public var conditional: Conditional<RP>
    public var metadata: RP.ItemMetadata?

    public init(
        code: RPReferenceCode,
        displayName: String? = nil,
        maximumStack: Int? = nil,
        components: [Component<RP>] = [],
        ability: Ability<RP>? = nil,
        conditional: Conditional<RP> = .always
    ) {
        self.code = code
        self.displayName = displayName ?? code
        self.maximumStack = maximumStack
        self.components = components
        self.ability = ability
        self.conditional = conditional
    }
}

public struct RPActiveItem<RP: RPSpace>: Temporal, Codable, Equatable {
    public var id: RPItemId = UUID().uuidString
    public var item: RPItem<RP>
    public var amount: Int
    public var entity: RPEntityId?

    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement { item.ability?.cooldown ?? 0 }

    public var code: RPReferenceCode { item.code }
    public var displayName: String { item.displayName }
    public var stats: RP.Stats { item.stats }

    public init(
        item: RPItem<RP>,
        amount: Int = 1,
        entity: RPEntityId? = nil
    ) {
        self.item = item
        self.amount = amount
        self.entity = entity
    }

    public func hasCapacity(for additionalAmount: Int) -> Bool {
        guard let maximumStack = item.maximumStack else { return true }
        return amount + additionalAmount <= maximumStack
    }

    public var remainingCapacity: Int? {
        item.maximumStack.map { max(0, $0 - amount) }
    }

    public func canExecute(in rpSpace: RP) -> Bool {
        guard isCoolingDown() == false else {
            return false
        }

        guard let entityId = entity,
              let e = rpSpace.entityById(entityId),
              let a = item.ability,
              a.cost < e.currentStats
        else {
            return false
        }

        return (try? item.conditional.exec(e, rpSpace: rpSpace)) ?? false
    }

    public func getPendingEvents(in rpSpace: RP) -> [Event<RP>] {
        guard isCoolingDown() == false else {
            return []
        }
        return createEvents(in: rpSpace)
    }

    fileprivate func createEvents(in rpSpace: RP) -> [Event<RP>] {
        guard let ability = item.ability,
              let entityId = entity
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
