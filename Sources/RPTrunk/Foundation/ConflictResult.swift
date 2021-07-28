
public struct ConflictResult: Equatable {
    public let entity: Id<Entity>
    public let change: Stats
    public let meta: [String: RPValue]

    public init(_ entity: Entity, _ change: Stats, _ meta: [String: RPValue] = [:]) {
        self.entity = entity.id
        self.change = change
        self.meta = meta
    }
    
    public init(entityId: Id<Entity>, _ change: Stats, _ meta: [String: RPValue] = [:]) {
        self.entity = entityId
        self.change = change
        self.meta = meta
    }
}
