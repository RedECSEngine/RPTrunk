
public protocol Storable {
    var id: String { get }
    var name: String { get }
}

public protocol Wearable: Storable {
    var component: Component? { get }
}

public struct Item: Storable {
    public let id = UUID().uuidString
    public let name = "Unititled Item"
}

public struct Armor: Wearable {
    public let id = UUID().uuidString
    public let name = "Unititled Armor"
    public let component:Component?
    public var stats: Stats {
        return component?.getStats() ?? Stats([:])
    }
}

public struct Weapon: Wearable {
    public let id = UUID().uuidString
    public let name = "Unititled Weapon"
    public let component: Component?
    public var stats: Stats {
        return component?.getStats() ?? Stats([:])
    }
}

public protocol InventoryManager: class {
    var inventory: [Storable] { get set }
}

public struct Body {
    let weapons: [Weapon] = []
    let equipment: [Armor] = []
}
