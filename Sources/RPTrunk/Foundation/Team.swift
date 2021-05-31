public class Team: InventoryManager, Codable {
    public let id: Id<Team>
    public private(set) var entities: Set<Entity> = []
    public var allies: Set<Id<Team>> = []
    public var enemies: Set<Id<Team>> = []

    public var inventory: [Item] = []

    public init(id: Id<Team> = .init()) {
        self.id = id
    }

    public func add(_ entity: Entity) {
        entity.teamId = id
        entities.insert(entity)
    }
}
