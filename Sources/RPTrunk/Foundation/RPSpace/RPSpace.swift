public typealias RPEntityId = String
public typealias RPTeamId = String
public typealias RPItemId = String
public typealias RPEventId = String
public typealias RPReferenceCode = String

public protocol RPMetadata: Codable & Equatable {}
public struct EmptyMetadataDictionary: RPMetadata, Sendable {
    public init() {}
}

public protocol RPSpace: Codable {

    associatedtype Stats: StatsType

    associatedtype EntityMetadata: RPMetadata = EmptyMetadataDictionary
    associatedtype ItemMetadata: RPMetadata = EmptyMetadataDictionary
    associatedtype AbilityMetadata: RPMetadata = EmptyMetadataDictionary

    typealias Entity = RPEntity<Self>
    associatedtype EntitySequence: Sequence where EntitySequence.Element == RPEntityId

    typealias Team = RPTeam<Self>
    associatedtype TeamSequence: Sequence where TeamSequence.Element == RPTeamId

    typealias ActiveItem = RPActiveItem<Self>
    associatedtype ItemSequence: Sequence where ItemSequence.Element == RPItemId
    
    static var statTypes: Set<String> { get }

    static func createDefaultEntity(cache: RPCache<Self>) -> Entity
    
    /// How any interaction between to entities in resolves.
    ///  Events contain all the data necessary to calculate an end result
    static func resolveConflict(
        _ event: Event<Self>,
        in rpSpace: Self,
        target: RPEntityId,
        conflict: Stats
    ) -> ConflictResult<Self>

    /// How events translate into threat between entities. Declared as a
    /// requirement so conformances can customize it; the default
    /// implementation produces no threat, leaving the system dormant.
    static func resolveThreatChanges(
        for eventResult: EventResult<Self>,
        in rpSpace: Self
    ) -> [ThreatChange]

    func entityById(_ id: RPEntityId) -> Entity?
    func teamById(_ id: RPTeamId) -> Team?
    func itemById(_ id: RPItemId) -> ActiveItem?

    func allEntities() -> EntitySequence
    func allTeams() -> TeamSequence
    func allItems() -> ItemSequence
    func allPendingGameMasterEvents() -> [Event<Self>]

    mutating func addEntity(_ entity: Entity)
    mutating func setTeams(_ newTeams: [Team])
    mutating func addItem(_ item: ActiveItem)
    mutating func removeItem(id: RPItemId)
    mutating func queueGameMasterEvent(_ event: Event<Self>)
    mutating func removeGameMasterEvent(id: RPEventId)

    mutating func modifyEntity(id: RPEntityId, perform: (inout Entity, Self) -> Void)
    mutating func modifyTeam(id: RPTeamId, perform: (inout Team, Self) -> Void)
    mutating func modifyItem(id: RPItemId, perform: (inout ActiveItem, Self) -> Void)

}

public extension RPSpace {
    
    static var statTypes: Set<String> { Set(Stats.dynamicKeys.keys) }
    
    static func createDefaultEntity(cache: RPCache<Self>) -> Entity {
        Entity()
    }
    
    func getEnemies(of entityId: RPEntityId) -> Set<RPEntityId> {
        guard let entity = entityById(entityId),
              let teamId = entity.teamId,
              let team = teamById(teamId)
        else {
            return []
        }

        return team.enemies.reduce(Set()) {
            accumulated, enemyTeamId -> Set<RPEntityId> in

            guard let enemies = teamById(enemyTeamId)?.entities else {
                return accumulated
            }
            return accumulated.union(enemies)
        }
    }
    
    func getFriends(of entityId: RPEntityId) -> Set<RPEntityId> {
        guard let entity = entityById(entityId),
              let teamId = entity.teamId,
              let team = teamById(teamId)
        else {
            return []
        }
        return team.entities.union(getAllies(of: entityId))
    }
    
    func getAllies(of entityId: RPEntityId) -> Set<RPEntityId> {
        guard let entity = entityById(entityId),
              let teamId = entity.teamId,
              let team = teamById(teamId)
        else {
            return []
        }
        
        return team.allies.reduce(Set()) {
            accumulated, allyTeamId -> Set<RPEntityId> in
            
            guard let enemies = teamById(allyTeamId)?.entities else {
                return accumulated
            }
            return accumulated.union(enemies)
        }
    }
}

extension RPSpace {
    public mutating func tick(_ moment: Moment) {
        allTeams()
            .compactMap(teamById)
            .flatMap(\.entities)
            .forEach {
                modifyEntity(id: $0) { e, _ in
                    e.tick(moment)
                }
            }
    }
    
    public func getPendingEvents() -> [Event<Self>] {
        allPendingGameMasterEvents() +
        getAllPendingPassiveEvents() +
        getAllPendingStatusEffectEvents() +
        getAllPendingExecutableEvents()
    }

    public func getAllPendingPassiveEvents() -> [Event<Self>] {
        allTeams()
            .compactMap(teamById)
            .flatMap(\.entities)
            .compactMap(entityById)
            .flatMap { $0.getPendingPassiveEvents(in: self) }
    }

    /// Periodic events emitted by active status effects (heal/damage over time,
    /// e.g. Regen and Bleed). Without this, status effects tick internally but
    /// their per-tick events are never collected, so only the ability's initial
    /// application is felt.
    public func getAllPendingStatusEffectEvents() -> [Event<Self>] {
        allTeams()
            .compactMap(teamById)
            .flatMap(\.entities)
            .compactMap(entityById)
            .flatMap { $0.getPendingStatusEffectEvents(in: self) }
    }

    public func getAllPendingExecutableEvents() -> [Event<Self>] {
        allTeams()
            .compactMap(teamById)
            .flatMap(\.entities)
            .compactMap(entityById)
            .flatMap { $0.getPendingExecutableEvents(in: self) }
    }

    public mutating func performEvents(_ events: [Event<Self>]) -> [EventResult<Self>] {
        events.forEach { event in
            self.removeGameMasterEvent(id: event.id)
        }

        let mainEventResults = events
            .flatMap { event -> [Event<Self>] in
                event.resetInitiatorCooldowns(in: &self)
                return [event]
            }
            .map { $0.execute(in: &self) }
        
        let reactionEventResults = mainEventResults.flatMap {
            eventResult -> [Event<Self>] in
            eventResult.effects.flatMap {
                conflictResult -> [Event<Self>] in
                entityById(conflictResult.entity)?.getPendingPassiveEvents(in: self) ?? []
            }
        }
        .map { $0.execute(in: &self) }

        return mainEventResults + reactionEventResults
    }

}

public struct ItemTransfer: Codable, Equatable {
    public let itemId: RPItemId
    public let code: RPReferenceCode
    public let amount: Int
    public let from: RPEntityId?
    public let to: RPEntityId

    public init(itemId: RPItemId, code: RPReferenceCode, amount: Int, from: RPEntityId?, to: RPEntityId) {
        self.itemId = itemId
        self.code = code
        self.amount = amount
        self.from = from
        self.to = to
    }
}

extension RPSpace {
    @discardableResult
    public mutating func receiveItem(
        _ incoming: ActiveItem,
        to recipientId: RPEntityId,
        from sourceId: RPEntityId? = nil
    ) -> [ItemTransfer] {
        guard incoming.amount > 0, entityById(recipientId) != nil else {
            if itemById(incoming.id) != nil { removeItem(id: incoming.id) }
            return []
        }
        var remaining = incoming.amount
        var destinationId: RPItemId?
        for stackId in entityById(recipientId)?.inventory ?? [] where stackId != incoming.id {
            guard remaining > 0 else { break }
            guard let stack = itemById(stackId), stack.code == incoming.code else { continue }
            let capacity = stack.remainingCapacity ?? remaining
            guard capacity > 0 else { continue }
            let moved = Swift.min(remaining, capacity)
            modifyItem(id: stackId) { s, _ in s.amount += moved }
            remaining -= moved
            if destinationId == nil { destinationId = stackId }
        }
        let existsInStore = itemById(incoming.id) != nil
        if remaining > 0 {
            if existsInStore {
                modifyItem(id: incoming.id) { s, _ in
                    s.amount = remaining
                    s.entity = recipientId
                }
            } else {
                var newStack = incoming
                newStack.amount = remaining
                newStack.entity = recipientId
                addItem(newStack)
            }
            modifyEntity(id: recipientId) { e, _ in e.inventory.append(incoming.id) }
            if destinationId == nil { destinationId = incoming.id }
        } else if existsInStore {
            removeItem(id: incoming.id)
        }
        return [ItemTransfer(
            itemId: destinationId ?? incoming.id,
            code: incoming.code,
            amount: incoming.amount,
            from: sourceId,
            to: recipientId
        )]
    }

    @discardableResult
    public mutating func transferItem(id: RPItemId, to recipientId: RPEntityId) -> [ItemTransfer] {
        guard let active = itemById(id), active.entity != recipientId else { return [] }
        let sourceId = active.entity
        if let sourceId = sourceId {
            modifyEntity(id: sourceId) { e, _ in
                e.inventory.removeAll { $0 == id }
                e.body.wornItems.removeAll { $0 == id }
            }
        }
        return receiveItem(active, to: recipientId, from: sourceId)
    }

    @discardableResult
    public mutating func transferAllItems(from sourceId: RPEntityId, to recipientId: RPEntityId) -> [ItemTransfer] {
        guard let source = entityById(sourceId) else { return [] }
        let itemIds = source.inventory + source.body.wornItems.filter { !source.inventory.contains($0) }
        return itemIds.flatMap { transferItem(id: $0, to: recipientId) }
    }

    public func collectAllEvent(from sourceId: RPEntityId, to recipientId: RPEntityId) -> Event<Self> {
        Event(
            category: .itemExchangeOnly,
            initiator: sourceId,
            ability: Ability<Self>(
                code: "collect",
                components: [Component(itemExchange: ItemExchange(kind: .transferAll))]
            ),
            targets: [recipientId],
            rpSpace: self
        )
    }
}
