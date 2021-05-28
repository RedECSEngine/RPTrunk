
public struct ConflictResult {

    public let entity: Entity
    public let change: Stats
    public let meta: [String: RPValue]

    public init(_ entity:Entity, _ change:Stats, _ meta:[String: RPValue] = [:]) {

        self.entity = entity
        self.change = change
        self.meta = meta
    }
    
}
