public class Team: InventoryManager {
    public typealias TeamID = String

    public let id: TeamID
    public private(set) var entities: Set<Entity> = []
    public var allies: Set<TeamID> = []
    public var enemies: Set<TeamID> = []

    public var inventory: [Item] = []

    public init(id: String) {
        self.id = id
    }

    public func add(_ entity: Entity) {
        entity.teamId = id
        entities.insert(entity)
    }
}
