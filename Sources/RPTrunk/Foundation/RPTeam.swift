public struct RPTeam<RP: RPSpace>: Codable, Equatable {
    public var id: RPTeamId = UUID().uuidString
    public private(set) var entities: Set<RPEntityId> = []
    public var allies: Set<RPTeamId> = []
    public var enemies: Set<RPTeamId> = []

    public var inventory: [RPActiveItem<RP>] = []
    
    public init() { }

    public mutating func add(_ entity: inout RPEntity<RP>) {
        entity.teamId = id
        entities.insert(entity.id)
    }
}
