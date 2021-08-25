
public struct ConflictResult<RP: RPSpace>: Equatable {
    public let entity: RPEntityId
    public let change: RP.Stats
    public let meta: [String: RPValue]

    public init(_ entity: RPEntity<RP>, _ change: RP.Stats, _ meta: [String: RPValue] = [:]) {
        self.entity = entity.id
        self.change = change
        self.meta = meta
    }
    
    public init(entityId: RPEntityId, _ change: RP.Stats, _ meta: [String: RPValue] = [:]) {
        self.entity = entityId
        self.change = change
        self.meta = meta
    }
}
