public struct Team {
    public var entities:[Entity]
    
    public init(entities: [Entity]) {
        self.entities = entities
    }
}

open class Battle: Temporal {
    
    open var currentTick: Double = 0
    open var maximumTick: Double = 0
    
    open var teams = [Team]()
    
    public init() {
        
    }
    
    open func tick(_ moment:Moment) -> [Event] {
        
        let newMoment = moment.addSibling(self)
        return teams
            .flatMap { $0.entities }
            .flatMap { $0.tick(newMoment) }
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
        
        return events
            .flatMap { event -> [Event] in
                
                event.initiator.resetCooldown()
                
                let pre = self.teams
                    .flatMap { $0.entities }
                    .flatMap { $0.eventWillOccur(event) }
                let during = [event]
                let post = self.teams
                    .flatMap { $0.entities }
                    .flatMap { $0.eventDidOccur(event) }
                return pre + during + post
            }
            .map { $0.execute() }
    }
    
    public func resetCooldown() {
        
    }
}
