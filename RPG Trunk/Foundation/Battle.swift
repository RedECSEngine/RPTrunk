public struct Team {
    public var entities:[Entity]
    
    public init(entities: [Entity]) {
        self.entities = entities
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
            .flatMap { $0.getPendingPassiveEvents() }
            .reduce([], +)
    }
    
    open func getAllPendingExecutableEvents() -> [Event] {
        return teams
            .flatMap { $0.entities }
            .flatMap { $0.getPendingExecutableEvents() }
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
                return conflictResult.entity.getPendingPassiveEvents()
            })
        }
        .map { $0.execute() }
        
        return mainEventResults + reactionEventResults
    }
    
}
