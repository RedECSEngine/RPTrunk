public struct RPTeam {
    let entities:[RPEntity]
}

public class RPBattle {
    
    public var entities:[RPEntity] = []
    
    public var teams = [RPTeam]()
    
    public init() { }
    
    public func tick() -> [(Event, [ConflictResult])] {
        
        return entities
            .flatMap { $0.tick() }
            |> performEvents
    }
    
    private func performEvents(events:[Event]) -> [(Event, [ConflictResult])] {
        
        return events
            .flatMap { event -> [Event] in
                let pre = self.entities.flatMap { $0.eventWillOccur(event) }
                let during = [event]
                let post = self.entities.flatMap { $0.eventDidOccur(event) }
                return pre + during + post
            }
            .map { ($0, $0.execute()) }
    }
}