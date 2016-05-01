
public protocol Storable {
    var name:String { get }
}

public protocol Wearable: Storable, StatsContainer {
    var component:Component? { get }
}

public struct Item: Storable {
    public let name = "Unititled Item"
}

public struct Armor: Wearable {
    public let name = "Unititled Armor"
    public let component:Component?
    public var stats:RPStats {
        return component?.getStats() ?? RPStats([:])
    }
}

public struct Weapon: Wearable {
    public let name = "Unititled Weapon"
    public let component:Component?
    public var stats:RPStats {
        return component?.getStats() ?? RPStats([:])
    }
}

public struct Storage {
    let items:[Storable] = []
}

public struct Body {
    let weapons:[Weapon] = []
    let equipment:[Armor] = []
    let storage = Storage()
}