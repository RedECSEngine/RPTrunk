
public struct ConflictResult {

    public let entity:Entity
    public let change:Stats

    init(_ entity:Entity, _ change:Stats) {

        self.entity = entity
        self.change = change
    }
}
