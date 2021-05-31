public class RPSpace: Temporal, InventoryManager {
    public var inventory: [Item] = []
    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement = -1

    open private(set) var entities: [Id<Entity>: Entity] = [:]
    open private(set) var teams: [Id<Team>: Team] = [:]

    public init() {}

    public func setTeams(_ newTeams: [Team]) {
        var teamDict: [Id<Team>: Team] = [:]
        newTeams.forEach { team in
            teamDict[team.id] = team
            team.entities.forEach { entities[$0.id] = $0 }
        }
        teams = teamDict
    }

    open func tick(_ moment: Moment) {
        let newMoment = moment.addSibling(self)
        teams.values
            .flatMap(\.entities)
            .forEach { $0.tick(newMoment) }
    }

    public func getPendingEvents() -> [Event] {
        getPendingEvents(in: self)
    }

    public func getPendingEvents(in _: RPSpace) -> [Event] {
        getAllPendingPassiveEvents() + getAllPendingExecutableEvents()
    }

    private func getAllPendingPassiveEvents() -> [Event] {
        teams.values
            .flatMap(\.entities)
            .flatMap { $0.getPendingPassiveEvents(in: self) }
    }

    private func getAllPendingExecutableEvents() -> [Event] {
        teams.values
            .flatMap(\.entities)
            .flatMap { $0.getPendingExecutableEvents(in: self) }
    }

    open func performEvents(_ events: [Event]) -> [EventResult] {
        let mainEventResults = events
            .flatMap { event -> [Event] in
                event.resetCooldowns()
                return [event]
            }
            .map { $0.execute(in: self) }

        let reactionEventResults = mainEventResults.flatMap {
            eventResult -> [Event] in
            eventResult.effects.flatMap {
                conflictResult -> [Event] in
                conflictResult.entity.getPendingPassiveEvents(in: self)
            }
        }
        .map { $0.execute(in: self) }

        return mainEventResults + reactionEventResults
    }

    // TODO: hook it in
    open func give(item: Item, to entity: Entity) -> Event {
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

    open func getEntities() -> Set<Entity> {
        teams.values
            .reduce(Set()) {
                accumulated, team -> Set<Entity> in
                accumulated.union(team.entities)
            }
    }

    open func getEnemies(of entity: Entity) -> Set<Entity> {
        guard let teamId = entity.teamId,
              let team = teams[teamId]
        else {
            return []
        }

        return team.enemies.reduce(Set()) {
            accumulated, enemyTeamId -> Set<Entity> in

            guard let enemies = teams[enemyTeamId]?.entities else {
                return accumulated
            }
            return accumulated.union(enemies)
        }
    }

    open func getFriends(of entity: Entity) -> Set<Entity> {
        guard let teamId = entity.teamId,
              let team = teams[teamId]
        else {
            return []
        }

        let teamEntities = team.entities
        return teamEntities.union(getAllies(of: entity))
    }

    open func getAllies(of entity: Entity) -> Set<Entity> {
        guard let teamId = entity.teamId,
              let team = teams[teamId]
        else {
            return []
        }

        return team.allies.reduce(Set()) {
            accumulated, allyTeamId -> Set<Entity> in

            guard let enemies = teams[allyTeamId]?.entities else {
                return accumulated
            }
            return accumulated.union(enemies)
        }
    }

    public func resetCooldown() { /* noop */ }
}
