
public protocol InventoryManager: class {
    var inventory: [Item] { get set }
}

public struct Body: Codable {
    let wornItems: [Item] = []
}
