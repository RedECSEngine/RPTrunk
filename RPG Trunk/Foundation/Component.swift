
public protocol Component {
    var stats:RPStats { get }
}

public struct StatsComponent: Component {
    public let stats:RPStats
    public init(_ data:[String:RPValue]) {
        self.stats = RPStats(data)
    }
}

