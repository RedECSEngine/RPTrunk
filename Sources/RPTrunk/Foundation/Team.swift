public struct Team: InventoryManager, Codable {
    public let id: Id<Team>
    public private(set) var entities: Set<Id<Entity>> = []
    public var allies: Set<Id<Team>> = []
    public var enemies: Set<Id<Team>> = []

    public var inventory: [Item] = []

    public init(id: Id<Team> = .init()) {
        self.id = id
    }

    public mutating func add(_ entity: inout Entity) {
        entity.teamId = id
        entities.insert(entity.id)
    }
}
