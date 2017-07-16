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
        
        let battleEvents = [Event]()
        let newMoment = moment.addSibling(self)
        return teams
            .flatMap { $0.entities }
            .flatMap { $0.tick(newMoment) }
            .reduce(battleEvents, +)
    }
    
//    open func remove(_ entity: Entity) {
//        
//        var location: (team: Int, index: Int)?
//        
//        for (teamIndex, team) in teams.enumerated() {
//            if let entityIndex = team.entities.index(where: { $0 === entity }) {
//                location = (team: teamIndex, index: entityIndex)
//                break
//            }
//        }
//        
//        guard let loc = location else {
//            return
//        }
//        
//        teams[loc.team].entities.remove(at: loc.index)
//    }
    
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
    
    public func resetCooldown() {
        
    }
}
