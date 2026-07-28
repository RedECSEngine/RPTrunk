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

    static var statTypes: Set<String> { get }

    static func createDefaultEntity(cache: RPCache<Self>) -> Entity
    
    /// Where we calculate any relationship between stats to determine to final values
    /// e.g. where we calculate how stamina translates to HP
    /// or any other kinds of specialized game state that could impact final stats
    static func fullyResolvedStats(for stats: Self.Stats) -> Self.Stats

    /// How any interaction between to entities in resolves.
    /// Events contain all the data necessary to calculate an end result
    static func resolveConflict(
        _ event: RPEvent<Self>,
        in rpSpace: Self,
        target: RPEntityId,
        conflict: Stats
    ) -> RPConflictResult<Self>

    /// How events translate into threat between entities. Declared as a
    /// requirement so conformances can customize it; the default
    /// implementation produces no threat, leaving the system dormant.
    static func resolveThreatChanges(
        for eventResult: RPEventResult<Self>,
        in rpSpace: Self
    ) -> [RPThreatChange]

    func entityById(_ id: RPEntityId) -> Entity?
    func teamById(_ id: RPTeamId) -> Team?

    func allEntities() -> EntitySequence
    func allTeams() -> TeamSequence
    func allPendingGameMasterEvents() -> [RPEvent<Self>]

    mutating func addEntity(_ entity: Entity)
    mutating func setTeams(_ newTeams: [Team])
    mutating func queueGameMasterEvent(_ event: RPEvent<Self>)
    mutating func removeGameMasterEvent(id: RPEventId)

    mutating func modifyEntity(id: RPEntityId, perform: (inout Entity, Self) -> Void)
    mutating func modifyTeam(id: RPTeamId, perform: (inout Team, Self) -> Void)

}

public extension RPSpace {
    
    static var statTypes: Set<String> { Set(Stats.dynamicKeys.keys) }
    
    static func createDefaultEntity(cache: RPCache<Self>) -> Entity {
        Entity()
    }
    
    static func fullyResolvedStats(for rpEntity: RPEntity<Self>) -> Stats {
        fullyResolvedStats(for: rpEntity.cumulativeWornStats())
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
    public mutating func tick(_ moment: RPMoment) {
        allTeams()
            .compactMap(teamById)
            .flatMap(\.entities)
            .forEach {
                modifyEntity(id: $0) { e, _ in
                    e.tick(moment)
                }
            }
    }
    
    public func getPendingEvents() -> [RPEvent<Self>] {
        allPendingGameMasterEvents() +
        getAllPendingPassiveEvents() +
        getAllPendingStatusEffectEvents() +
        getAllPendingExecutableEvents()
    }

    public func getAllPendingPassiveEvents() -> [RPEvent<Self>] {
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
    public func getAllPendingStatusEffectEvents() -> [RPEvent<Self>] {
        allTeams()
            .compactMap(teamById)
            .flatMap(\.entities)
            .compactMap(entityById)
            .flatMap { $0.getPendingStatusEffectEvents(in: self) }
    }

    public func getAllPendingExecutableEvents() -> [RPEvent<Self>] {
        allTeams()
            .compactMap(teamById)
            .flatMap(\.entities)
            .compactMap(entityById)
            .flatMap { $0.getPendingExecutableEvents(in: self) }
    }

    public mutating func performEvents(_ events: [RPEvent<Self>]) -> [RPEventResult<Self>] {
        events.forEach { event in
            self.removeGameMasterEvent(id: event.id)
        }

        let mainEventResults = events
            .flatMap { event -> [RPEvent<Self>] in
                switch event.category {
                case .standardConflict:
                    event.resetInitiatorCooldowns(in: &self)
                case .periodicEffect, .itemExchangeOnly:
                    break
                }
                return [event]
            }
            .map { $0.execute(in: &self) }
        
        let reactionEventResults = mainEventResults.flatMap {
            eventResult -> [RPEvent<Self>] in
            eventResult.effects.flatMap {
                conflictResult -> [RPEvent<Self>] in
                entityById(conflictResult.entity)?.getPendingPassiveEvents(in: self) ?? []
            }
        }
        .map { $0.execute(in: &self) }

        return mainEventResults + reactionEventResults
    }

}

public struct RPItemTransfer: Codable, Equatable {
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
    ) -> [RPItemTransfer] {
        guard incoming.amount > 0, entityById(recipientId) != nil else {
            return []
        }
        modifyEntity(id: recipientId) { e, _ in
            var remaining = incoming.amount
            for index in e.inventory.indices {
                guard remaining > 0 else { break }
                guard e.inventory[index].code == incoming.code else { continue }
                let capacity = e.inventory[index].remainingCapacity ?? remaining
                guard capacity > 0 else { continue }
                let moved = Swift.min(remaining, capacity)
                e.inventory[index].amount += moved
                remaining -= moved
            }
            if remaining > 0 {
                var newStack = incoming
                newStack.amount = remaining
                e.inventory.append(newStack)
            }
        }
        return [RPItemTransfer(
            itemId: incoming.id,
            code: incoming.code,
            amount: incoming.amount,
            from: sourceId,
            to: recipientId
        )]
    }

    @discardableResult
    public mutating func transferItem(id: RPItemId, from sourceId: RPEntityId, to recipientId: RPEntityId) -> [RPItemTransfer] {
        guard sourceId != recipientId, let source = entityById(sourceId) else { return [] }
        guard let outgoing = (source.inventory + source.body.wornItems).first(where: { $0.id == id }) else {
            return []
        }
        modifyEntity(id: sourceId) { e, _ in
            e.inventory.removeAll { $0.id == id }
            e.body.unequip(itemId: id)
        }
        return receiveItem(outgoing, to: recipientId, from: sourceId)
    }

    @discardableResult
    public mutating func transferAllItems(from sourceId: RPEntityId, to recipientId: RPEntityId) -> [RPItemTransfer] {
        guard sourceId != recipientId, let source = entityById(sourceId) else { return [] }
        let outgoing = source.inventory + source.body.wornItems
        modifyEntity(id: sourceId) { e, _ in
            e.inventory = []
            e.body.unequipAll()
        }
        return outgoing.flatMap { receiveItem($0, to: recipientId, from: sourceId) }
    }

    /// Moves a carried item out of the inventory and onto the body. Fails when
    /// the entity is not carrying `id`, the item has no `equipmentSlotCode`, or
    /// its slot is already full.
    @discardableResult
    public mutating func equipItem(id: RPItemId, on entityId: RPEntityId) -> Bool {
        guard let entity = entityById(entityId),
              let item = entity.inventory.first(where: { $0.id == id }),
              entity.body.canEquip(item)
        else {
            return false
        }
        modifyEntity(id: entityId) { e, _ in
            e.inventory.removeAll { $0.id == id }
            e.body.equip(item)
        }
        return true
    }

    /// Moves a worn item off the body and back into the inventory.
    @discardableResult
    public mutating func unequipItem(id: RPItemId, on entityId: RPEntityId) -> Bool {
        guard entityById(entityId)?.body.wornItems.contains(where: { $0.id == id }) == true else {
            return false
        }
        modifyEntity(id: entityId) { e, _ in
            guard let removed = e.body.unequip(itemId: id) else { return }
            e.inventory.append(removed)
        }
        return true
    }

    public func collectAllEvent(from sourceId: RPEntityId, to recipientId: RPEntityId) -> RPEvent<Self> {
        RPEvent(
            category: .itemExchangeOnly,
            initiator: sourceId,
            ability: RPAbility<Self>(
                code: "collect",
                fragments: [RPFragment(itemExchange: RPItemExchange(kind: .transferAll))]
            ),
            targets: [recipientId],
            rpSpace: self
        )
    }
}
