/// A single adjustment to one body's threat toward another, produced by
/// `RPSpace.resolveThreatChanges` after an event resolves.
public struct RPThreatChange: Equatable, Codable {
    /// The body whose threat table changes.
    public var holder: RPBodyId
    /// The body the threat is held toward.
    public var toward: RPBodyId
    /// Positive builds threat, negative reduces it. Threat is clamped at
    /// zero and zero entries are removed from the table.
    public var delta: RPValue

    public init(holder: RPBodyId, toward: RPBodyId, delta: RPValue) {
        self.holder = holder
        self.toward = toward
        self.delta = delta
    }
}

public extension RPSpace {
    /// This default produces no threat, leaving the feature dormant until this function is implemented
    static func resolveThreatChanges(
        for eventResult: RPEventResult<Self>,
        in rpSpace: Self
    ) -> [RPThreatChange] {
        []
    }

    mutating func applyThreatChanges(_ changes: [RPThreatChange]) {
        for change in changes {
            modifyBody(id: change.holder) { body, _ in
                body.addThreat(toward: change.toward, amount: change.delta)
            }
        }
    }

    mutating func clearAllThreat(toward id: RPBodyId) {
        for holderId in allBodies() where holderId != id {
            modifyBody(id: holderId) { body, _ in
                body.clearThreat(toward: id)
            }
        }
    }

    func threatsAgainst(_ id: RPBodyId) -> [RPValue] {
        allBodies()
            .filter { $0 != id }
            .compactMap { bodyById($0)?.threat[id] }
    }

    func bodiesThreatening(_ id: RPBodyId) -> [RPBodyId] {
        allBodies()
            .filter { bodyById($0)?.holdsThreat(toward: id) == true }
            .sorted()
    }

    func isThreatened(_ id: RPBodyId) -> Bool {
        allBodies().contains { bodyById($0)?.holdsThreat(toward: id) == true }
    }
}
