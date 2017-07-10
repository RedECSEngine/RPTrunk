public struct Team {
    public let entities:[Entity]
    
    public init(entities: [Entity]) {
        self.entities = entities
    }
}

open class Battle: Entity {
    
    open var teams = [Team]()
    
    open override func tick(_ moment:Moment) -> [Event] {
        
        let battleEvents = super.tick(moment)
        let newMoment = moment.addSibling(self)
        return teams
            .flatMap { $0.entities }
            .flatMap { $0.tick(newMoment) }
            .reduce(battleEvents, +)
    }
    
    open func performEvents(_ events:[Event]) -> [EventResult] {
        
        return events
            .flatMap { event -> [Event] in
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
}
