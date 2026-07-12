/// A single adjustment to one entity's threat toward another, produced by
/// `RPSpace.resolveThreatChanges` after an event resolves.
public struct ThreatChange: Equatable, Codable {
    /// The entity whose threat table changes.
    public var holder: RPEntityId
    /// The entity the threat is held toward.
    public var toward: RPEntityId
    /// Positive builds threat, negative reduces it. Threat is clamped at
    /// zero and zero entries are removed from the table.
    public var delta: RPValue

    public init(holder: RPEntityId, toward: RPEntityId, delta: RPValue) {
        self.holder = holder
        self.toward = toward
        self.delta = delta
    }
}

public extension RPSpace {
    /// This default produces no threat, leaving the feature dormant until this function is implemented
    static func resolveThreatChanges(
        for eventResult: EventResult<Self>,
        in rpSpace: Self
    ) -> [ThreatChange] {
        []
    }

    mutating func applyThreatChanges(_ changes: [ThreatChange]) {
        for change in changes {
            modifyEntity(id: change.holder) { entity, _ in
                entity.addThreat(toward: change.toward, amount: change.delta)
            }
        }
    }

    mutating func clearAllThreat(toward id: RPEntityId) {
        for holderId in allEntities() where holderId != id {
            modifyEntity(id: holderId) { entity, _ in
                entity.clearThreat(toward: id)
            }
        }
    }

    func entitiesThreatening(_ id: RPEntityId) -> [RPEntityId] {
        allEntities()
            .filter { entityById($0)?.holdsThreat(toward: id) == true }
            .sorted()
    }

    func isThreatened(_ id: RPEntityId) -> Bool {
        allEntities().contains { entityById($0)?.holdsThreat(toward: id) == true }
    }
}
