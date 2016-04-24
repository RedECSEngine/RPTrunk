
public struct Ability: StatsContainer {
    public var name:String
    public var components:[Component]
    public var targetType:EventTargetType = .Oneself  // RPGEventTargetType

    public init(name:String, components:[Component]) {
        self.name = name
        self.components = components
    }
    
    public var stats:RPStats {
        return self.components.reduce(RPStats([:]), combine:combineComponentStatsToTotal)
    }
}

public func combineComponentStatsToTotal(total:RPStats, component:Component) -> RPStats {
    return total + component.stats
}