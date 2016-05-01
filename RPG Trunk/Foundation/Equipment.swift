
public protocol Storable {
    var name:String {get}
}

public protocol Wearable: Storable, StatsContainer {
    var component:Component? {get set}
}

public struct Item: Storable {
    public var name = "Unititled Item"
}

public struct Armor: Wearable {
    public var name = "Unititled Armor"
    public var component:Component?
    public var stats:RPStats {
        return component?.getStats() ?? RPStats([:])
    }
}

public struct Weapon: Wearable {
    public var name = "Unititled Weapon"
    public var component:Component?
    public var stats:RPStats {
        return component?.getStats() ?? RPStats([:])
    }
}

public struct Storage {
    let items:[Storable] = []
}
