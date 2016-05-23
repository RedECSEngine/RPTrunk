public struct Team {
    let entities:[Entity]
}

public class Battle: Entity {
    
    public var entities:[Entity] = []
    
    override public var targets: [Entity] {
        get {
            return entities
        }
        set {
            print("[RPTrunk--Warn]: Trying to set the targets of \(String(Battle)). Use self.entities for setter access (targets == entities)")
        }
    }
    
    public var teams = [Team]()
    
    public override func tick(moment:Moment) -> [Event] {
        
        let battleEvents = super.tick(moment)
        let newMoment = moment.addSibling(self)
        return entities
            .flatMap { $0.tick(newMoment) }
            .reduce(battleEvents, combine: +)
    }
    
    public func newMoment() -> [EventResult] {
    
        let eventsToExecute = tick(Moment(delta: 1))
        return performEvents(eventsToExecute)
    }
    
    private func performEvents(events:[Event]) -> [EventResult] {
        
        return events
            .flatMap { event -> [Event] in
                let pre = self.entities.flatMap { $0.eventWillOccur(event) }
                let during = [event]
                let post = self.entities.flatMap { $0.eventDidOccur(event) }
                return pre + during + post
            }
            .map { $0.execute() }
    }
}