
public protocol InventoryManager {
    associatedtype RP: RPSpace
    var inventory: [RPActiveItem<RP>] { get set }
}

public struct Body<RP: RPSpace>: Codable, Equatable {
    public var wornItems: [RPActiveItem<RP>] = []
    public init() {}
}
