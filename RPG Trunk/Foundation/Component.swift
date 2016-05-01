
public protocol Component {
    func getStats() -> RPStats?
    func getTargetType() -> EventTargetType?
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
    
    public func getTargetType() -> EventTargetType? {
        return nil
    }
}

public struct TargetingComponent: Component {
    
    public let targetType:EventTargetType
    
    public func getTargetType() -> EventTargetType? {
        return targetType
    }

    public func getStats() -> RPStats? {
        return nil
    }
}