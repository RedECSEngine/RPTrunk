public protocol RPSpace: InventoryManager, Codable {
    var inventory: [Item] { get set }
    var currentTick: RPTimeIncrement { get set }
    var maximumTick: RPTimeIncrement { get }

    func entityById(_ id: Id<Entity>) -> Entity?
    func teamById(_ id: Id<Team>) -> Team?

    mutating func addEntity(_ entity: Entity)
    mutating func modifyEntity(id: Id<Entity>, perform: (inout Entity) -> Void)
    mutating func setTeams(_ newTeams: [Team])
    mutating func modifyTeam(id: Id<Team>, perform: (inout Team) -> Void)

    mutating func tick(_ moment: Moment)

    func getPendingEvents() -> [Event]
    func getAllPendingPassiveEvents() -> [Event]
    func getAllPendingExecutableEvents() -> [Event]

    mutating func performEvents(_ events: [Event]) -> [EventResult]

    mutating func give(item: Item, to entity: Entity) -> Event

    func getEntities() -> Set<Id<Entity>>
    func getEnemies(of entityId: Id<Entity>) -> Set<Id<Entity>>
    func getFriends(of entityId: Id<Entity>) -> Set<Id<Entity>>
    func getAllies(of entityId: Id<Entity>) -> Set<Id<Entity>>
}

public struct DefaultRPSpace: RPSpace, Equatable {
    public var inventory: [Item] = []
    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement = -1

    public var entities: [Id<Entity>: Entity] = [:]
    public var teams: [Id<Team>: Team] = [:]

    public init() {}
    
    public func entityById(_ id: Id<Entity>) -> Entity? {
        entities[id]
    }
    public func teamById(_ id: Id<Team>) -> Team? {
        teams[id]
    }
    
    public mutating func addEntity(_ entity: Entity) {
        assert(entities[entity.id] == nil, "attempting to add entity that already exists in this space")
        entities[entity.id] = entity
    }
    
    public mutating func modifyEntity(id: Id<Entity>, perform: (inout Entity) -> Void) {
        guard var entity = entities[id] else { return }
        perform(&entity)
        entities[id] = entity
    }
    
    public mutating func modifyTeam(id: Id<Team>, perform: (inout Team) -> Void) {
        guard var team = teams[id] else { return }
        perform(&team)
        teams[id] = team
    }

    public mutating func setTeams(_ newTeams: [Team]) {
        var teamDict: [Id<Team>: Team] = [:]
        newTeams.forEach { team in
            teamDict[team.id] = team
        }
        teams = teamDict
    }

    public mutating func tick(_ moment: Moment) {
        teams.values
            .flatMap(\.entities)
            .forEach {
                entities[$0]?.tick(moment)
            }
    }

    public func getPendingEvents() -> [Event] {
        getPendingEvents(in: self)
    }

    public func getPendingEvents(in _: RPSpace) -> [Event] {
        getAllPendingPassiveEvents() + getAllPendingExecutableEvents()
    }

    public func getAllPendingPassiveEvents() -> [Event] {
        teams.values
            .flatMap(\.entities)
            .compactMap { entities[$0] }
            .flatMap { $0.getPendingPassiveEvents(in: self) }
    }

    public func getAllPendingExecutableEvents() -> [Event] {
        teams.values
            .flatMap(\.entities)
            .compactMap { entities[$0] }
            .flatMap { $0.getPendingExecutableEvents(in: self) }
    }

    public mutating func performEvents(_ events: [Event]) -> [EventResult] {
        let mainEventResults = events
            .flatMap { event -> [Event] in
                event.resetCooldowns(in: &self)
                return [event]
            }
            .map { $0.execute(in: &self) }

        let reactionEventResults = mainEventResults.flatMap {
            eventResult -> [Event] in
            eventResult.effects.flatMap {
                conflictResult -> [Event] in
                entities[conflictResult.entity]?.getPendingPassiveEvents(in: self) ?? []
            }
        }
        .map { $0.execute(in: &self) }

        return mainEventResults + reactionEventResults
    }

    // TODO: hook it in
    public mutating func give(item: Item, to entity: Entity) -> Event {
        let exchange = Component(itemExchange: ItemExchange(exchangeType: .target, requiresInitiatorOwnItem: false, removesItemFromInitiator: false, item: item))
        let targeting = Component(targetType: Targeting(.oneself, .always))

        let collect = Ability(
            name: "",
            components: [
                exchange,
                targeting,
            ],
            cooldown: nil
        )

        let event = Event(category: .itemExchangeOnly, initiator: entity, ability: collect, rpSpace: self)
        return event
    }

    public func getEntities() -> Set<Id<Entity>> {
        teams.values
            .reduce(Set()) {
                accumulated, team -> Set<Id<Entity>> in
                accumulated.union(team.entities)
            }
    }

    public func getEnemies(of entityId: Id<Entity>) -> Set<Id<Entity>> {
        guard let entity = self.entities[entityId],
              let teamId = entity.teamId,
              let team = teams[teamId]
        else {
            return []
        }

        return team.enemies.reduce(Set()) {
            accumulated, enemyTeamId -> Set<Id<Entity>> in

            guard let enemies = teams[enemyTeamId]?.entities else {
                return accumulated
            }
            return accumulated.union(enemies)
        }
    }
    
    public func getFriends(of entityId: Id<Entity>) -> Set<Id<Entity>> {
        guard let entity = self.entities[entityId],
              let teamId = entity.teamId,
              let team = teams[teamId]
        else {
            return []
        }
        return team.entities.union(getAllies(of: entityId))
    }
    
    public func getAllies(of entityId: Id<Entity>) -> Set<Id<Entity>> {
        guard let entity = self.entities[entityId],
              let teamId = entity.teamId,
              let team = teams[teamId]
        else {
            return []
        }
        
        return team.allies.reduce(Set()) {
            accumulated, allyTeamId -> Set<Id<Entity>> in
            
            guard let enemies = teams[allyTeamId]?.entities else {
                return accumulated
            }
            return accumulated.union(enemies)
        }
    }

    public func resetCooldown() { /* noop */ }
}
