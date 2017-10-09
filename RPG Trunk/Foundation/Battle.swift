public struct Team {
    
    var id: String = UUID().uuidString
    public private(set) var entities: [Entity] = []
    
    public init() {
    
    }
    
    public mutating func add(_ entity: Entity) {
    
        entity.teamId = self.id
        entities.append(entity)
    }
}

open class Battle {
    
    open var teams = [Team]()
    
    public init() {
        
    }
    
    open func tick(_ moment:Moment) -> [Event] {
        return teams
            .flatMap { $0.entities }
            .flatMap { $0.tick(moment) }
            .reduce([], +)
    }
    
    open func getAllPendingPassiveEvents() -> [Event] {
        return teams
            .flatMap { $0.entities }
            .flatMap { $0.getPendingPassiveEvents(in: self) }
            .reduce([], +)
    }
    
    open func getAllPendingExecutableEvents() -> [Event] {
        return teams
            .flatMap { $0.entities }
            .flatMap { $0.getPendingExecutableEvents(in: self) }
            .reduce([], +)
    }
    
    open func performEvents(_ events:[Event]) -> [EventResult] {
        
        let mainEventResults = events
            .flatMap { event -> [Event] in
                event.initiator.resetCooldown()
                
                //reset cooldown if it is an executable
                event.initiator.resetAbility(byName: event.ability.name)
                return [event]
            }
            .map { $0.execute() }
        
        let reactionEventResults = mainEventResults.flatMap {
            (eventResult) -> [Event] in
            eventResult.effects.flatMap({
                conflictResult -> [Event] in
                return conflictResult.entity.getPendingPassiveEvents(in: self)
            })
        }
        .map { $0.execute() }
        
        return mainEventResults + reactionEventResults
    }
    
    open func getEntities() -> [Entity] {
        return teams
            .flatMap { $0.entities }
    }
    
    open func getEnemies(of entity: Entity) -> [Entity] {
        return teams
            .filter { $0.id != entity.teamId }
            .flatMap { $0.entities }
    }
    
    open func getFriends(of entity: Entity) -> [Entity] {
        return teams
            .filter { $0.id == entity.teamId }
            .flatMap { $0.entities }
    }
}
