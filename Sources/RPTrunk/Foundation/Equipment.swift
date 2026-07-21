
public protocol InventoryManager {
    associatedtype RP: RPSpace
    var inventory: [RPItemId] { get set }
}

public struct Body<RP: RPSpace>: Codable {
    public var wornItems: [RPItemId] = []
    public init() {}
}
