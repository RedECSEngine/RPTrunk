
public protocol Component {
    func getStats() -> RPStats?
    func getEvent(initiator:RPEntity, targets:[RPEntity]) -> Event?
}

public struct StatsComponent: Component {
    public let stats:RPStats
    public init(_ data:[String:RPValue]) {
        self.stats = RPStats(data)
    }
    public init( _ stats:RPStats) {
        self.stats = stats
    }
    
    public func getStats() -> RPStats? {
        return stats
    }
    
    public func getEvent(initiator:RPEntity, targets:[RPEntity]) -> Event? {
        return nil
    }
}

