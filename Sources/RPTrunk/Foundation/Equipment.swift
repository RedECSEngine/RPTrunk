
public protocol InventoryManager: AnyObject {
    var inventory: [Item] { get set }
}

public struct Body: Codable {
    var wornItems: [Item] = []
}
