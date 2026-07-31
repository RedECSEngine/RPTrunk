public struct RPTeam<RP: RPSpace>: Codable, Equatable {
    public var id: RPTeamId = UUID().uuidString
    public private(set) var bodies: Set<RPBodyId> = []
    public var allies: Set<RPTeamId> = []
    public var enemies: Set<RPTeamId> = []

    public var inventory: [RPActiveItem<RP>] = []
    
    public init() { }

    public mutating func add(_ body: inout RPBody<RP>) {
        body.teamId = id
        bodies.insert(body.id)
    }
}
