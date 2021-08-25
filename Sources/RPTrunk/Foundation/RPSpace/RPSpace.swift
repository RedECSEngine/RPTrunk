public typealias RPEntityId = String
public typealias RPTeamId = String
public typealias RPItemId = String
public typealias RPEventId = String

public protocol RPSpace: Codable {
    
    associatedtype Stats: StatsType
    
    typealias Entity = RPEntity<Self>
    associatedtype EntitySequence: Sequence where EntitySequence.Element == RPEntityId

    typealias Team = RPTeam<Self>
    associatedtype TeamSequence: Sequence where TeamSequence.Element == RPTeamId

    typealias Item = RPItem<Self>
    associatedtype ItemSequence: Sequence where ItemSequence.Element == RPItemId
    
    static var statTypes: Set<String> { get }

    static func createDefaultEntity(cache: RPCache<Self>) -> Entity
    
    static func resolveConflict(
        _ event: Event<Self>,
        in rpSpace: Self,
        target: RPEntityId,
        conflict: Stats
    ) -> ConflictResult<Self>
    
    func entityById(_ id: RPEntityId) -> Entity?
    func teamById(_ id: RPTeamId) -> Team?
    func itemById(_ id: RPItemId) -> Item?
    
    func allEntities() -> EntitySequence
    func allTeams() -> TeamSequence
    func allItems() -> ItemSequence
    func allPendingGameMasterEvents() -> [Event<Self>]

    mutating func addEntity(_ entity: Entity)
    mutating func setTeams(_ newTeams: [Team])
    mutating func addItem(_ item: Item)
    mutating func queueGameMasterEvent(ability: Ability<Self>, targets: Set<RPEntityId>)
    mutating func removeGameMasterEvent(id: RPEventId)
    
    mutating func modifyEntity(id: RPEntityId, perform: (inout Entity, Self) -> Void)
    mutating func modifyTeam(id: RPTeamId, perform: (inout Team, Self) -> Void)
    mutating func modifyItem(id: RPItemId, perform: (inout Item, Self) -> Void)

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
        getAllPendingExecutableEvents()
    }

    public func getAllPendingPassiveEvents() -> [Event<Self>] {
        allTeams()
            .compactMap(teamById)
            .flatMap(\.entities)
            .compactMap(entityById)
            .flatMap { $0.getPendingPassiveEvents(in: self) }
    }

    public func getAllPendingExecutableEvents() -> [Event<Self>] {
        allTeams()
            .compactMap(teamById)
            .flatMap(\.entities)
            .compactMap(entityById)
            .flatMap { $0.getPendingExecutableEvents(in: self) }
    }

    public mutating func performEvents(_ events: [Event<Self>]) -> [EventResult<Self>] {
        events.filter { $0.initiator == nil }
        .forEach { event in
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

    // TODO: hook it in
    public func give(item: RPItemId, to entity: RPEntityId) -> Event<Self> {
        guard let entity = entityById(entity) else {
            fatalError("no entity by that id")
        }
        let exchange = Component<Self>(
            itemExchange: ItemExchange(
                exchangeType: .target,
                requiresInitiatorOwnItem: false,
                removesItemFromInitiator: false,
                item: item
            )
        )
        let targeting = Component<Self>(targetType: Targeting(.oneself, .always))

        let collect = Ability<Self>(
            name: "",
            components: [
                exchange,
                targeting,
            ],
            cooldown: nil
        )

        return Event<Self>(category: .itemExchangeOnly, initiator: entity.id, ability: collect, rpSpace: self)
    }
}
