public struct RPTeam {
    let entities:[RPEntity]
}

public class RPBattle {
    
    public var entities:[RPEntity] = []
    
    public var teams = [RPTeam]()
    
    public init() { }
    
    public func tick() -> [(RPEvent, [RPConflictResult])] {
        
        return entities
            .flatMap { $0.tick() }
            |> performEvents
    }
    
    private func performEvents(events:[RPEvent]) -> [(RPEvent, [RPConflictResult])] {
        
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