
public protocol InventoryManager {
    associatedtype RP: RPSpace
    var inventory: [RPItemId] { get set }
}

public struct Body<RP: RPSpace>: Codable {
    var wornItems: [RPItemId] = []
}
