
public protocol Component {
    func getStats() -> RPStats?
    func getTargetType() -> EventTargetType?
    func getCost() -> RPStats?
}

public struct StatsComponent: Component, StatsContainer {
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
    
    public func getCost() -> RPStats? {
        return nil
    }
}

public struct CostComponent: Component, StatsContainer {
    public let stats:RPStats
    public init(_ data:[String:RPValue]) {
        self.stats = RPStats(data, asPartial: true)
    }
    public init( _ stats:RPStats) {
        self.stats = stats
    }
    
    public func getStats() -> RPStats? {
        return nil
    }
    
    public func getTargetType() -> EventTargetType? {
        return nil
    }
    
    public func getCost() -> RPStats? {
        return stats
    }
}

public struct TargetingComponent: Component {
    
    public let targetType:EventTargetType
    
    public init(_ targetType:EventTargetType) {
        self.targetType = targetType
    }
    
    public func getTargetType() -> EventTargetType? {
        return targetType
    }

    public func getStats() -> RPStats? {
        return nil
    }
    
    public func getCost() -> RPStats? {
        return nil
    }
}