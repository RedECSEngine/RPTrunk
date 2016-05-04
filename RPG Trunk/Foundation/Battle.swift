public struct RPTeam {
    let entities:[RPEntity]
}

public typealias EventResult = (RPEvent, [RPConflictResult])

public class RPBattle: RPEntity {
    
    public var entities:[RPEntity] = []
    
    override public var targets: [RPEntity] {
        get {
            return entities
        }
        set {
            print("[RPTrunk--Warn]: Trying to set the targets of \(String(RPBattle)). Use self.entities for setter access (targets == entities)")
        }
    }
    
    public var teams = [RPTeam]()
    
    public func tick() -> [EventResult] {
        
        let battleEvents = executeTickAndGetNewEvents()
        return entities
            .flatMap { $0.executeTickAndGetNewEvents() }
            .reduce(battleEvents, combine: +)
            |> performEvents
    }
    
    private func performEvents(events:[RPEvent]) -> [EventResult] {
        
        return events
            .flatMap { event -> [RPEvent] in
                let pre = self.entities.flatMap { $0.eventWillOccur(event) }
                let during = [event]
                let post = self.entities.flatMap { $0.eventDidOccur(event) }
                return pre + during + post
            }
            .map { ($0, $0.execute()) }
    }
}