
public protocol InventoryManager: class {
    var inventory: [Item] { get set }
}

public struct Body {
    let wornItems: [Item] = []
}
