
public protocol InventoryManager {
    var inventory: [Item] { get set }
}

public struct Body: Codable {
    var wornItems: [Item] = []
}
