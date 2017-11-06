public class Team: InventoryManager {
    
    public typealias TeamID = String
    
    public let id: TeamID
    public private(set) var entities: Set<Entity> = []
    public var allies: Set<TeamID> = []
    public var enemies: Set<TeamID> = []
    
    public var inventory: [Item] = []
    
    public init(id: String) {
        self.id = id
    }
    
    public func add(_ entity: Entity) {
    
        entity.teamId = self.id
        entities.insert(entity)
    }
}

open class RPSpace: Temporal, InventoryManager {

    public var inventory: [Item] = []
    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement = -1
    
    open var teams: [String: Team] = [:]
    
    public init() {
        
    }
    
    open func tick(_ moment: Moment) {
        let newMoment = moment.addSibling(self)
        teams.values
            .flatMap { $0.entities }
            .forEach { $0.tick(newMoment) }
    }
    
    public func getPendingEvents() -> [Event] {
        return getPendingEvents(in: self)
    }
    
    public func getPendingEvents(in rpSpace: RPSpace) -> [Event] {
        return getAllPendingPassiveEvents() + getAllPendingExecutableEvents()
    }

    private func getAllPendingPassiveEvents() -> [Event] {
        return teams.values
            .flatMap { $0.entities }
            .flatMap { $0.getPendingPassiveEvents(in: self) }
    }
    
    private func getAllPendingExecutableEvents() -> [Event] {
        return teams.values
            .flatMap { $0.entities }
            .flatMap { $0.getPendingExecutableEvents(in: self) }
    }
    
    open func performEvents(_ events:[Event]) -> [EventResult] {
        
        let mainEventResults = events
            .flatMap { event -> [Event] in
                event.resetCooldowns()
                return [event]
            }
            .map { $0.execute(in: self) }
        
        let reactionEventResults = mainEventResults.flatMap {
            (eventResult) -> [Event] in
            eventResult.effects.flatMap({
                conflictResult -> [Event] in
                return conflictResult.entity.getPendingPassiveEvents(in: self)
            })
        }
            .map { $0.execute(in: self) }
        
        return mainEventResults + reactionEventResults
    }
    
    //TODO: hook it in
    open func give(item: Item, to entity: Entity) -> Event {
        
        let exchange = ItemExchange(exchangeType: .target, requiresInitiatorOwnItem: false, removesItemFromInitiator: false, item: item)
        let targeting = Targeting.init(.oneself, .always)
        
        let collect = Ability(name: "", components: [
            exchange,
            targeting
        ], shouldUseDefaults: true, cooldown: nil)
        
        let event = Event(category: .itemExchangeOnly, initiator: entity, ability: collect, rpSpace: self)
        return event
    }
    
    open func getEntities() -> Set<Entity> {
        return teams.values
            .reduce(Set(), {
                (accumulated, team) -> Set<Entity> in
                return accumulated.union(team.entities)
            })
    }
    
    open func getEnemies(of entity: Entity) -> Set<Entity> {
        
        guard let teamId = entity.teamId
            , let team = teams[teamId] else {
            return []
        }
        
        return team.enemies.reduce(Set()) {
            (accumulated, enemyTeamId) -> Set<Entity> in
            
            guard let enemies = teams[enemyTeamId]?.entities else {
                return accumulated
            }
            return accumulated.union(enemies)
        }
    }
    
    open func getFriends(of entity: Entity) -> Set<Entity> {
        
        guard let teamId = entity.teamId
            , let team = teams[teamId] else {
                return []
        }
        
        let teamEntities = team.entities
        return teamEntities.union(getAllies(of: entity))
    }
    
    
    open func getAllies(of entity: Entity) -> Set<Entity> {
        
        guard let teamId = entity.teamId
            , let team = teams[teamId] else {
                return []
        }
        
        return team.allies.reduce(Set()) {
            (accumulated, allyTeamId) -> Set<Entity> in
            
            guard let enemies = teams[allyTeamId]?.entities else {
                return accumulated
            }
            return accumulated.union(enemies)
        }
    }
    
    public func resetCooldown() { /* noop */ }

}
