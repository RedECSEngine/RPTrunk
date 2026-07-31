
public struct RPConflictResult<RP: RPSpace>: Equatable, Codable {
    public let body: RPBodyId
    public let change: RP.Stats
    public let meta: [String: RPValue]

    public init(_ body: RPBody<RP>, _ change: RP.Stats, _ meta: [String: RPValue] = [:]) {
        self.body = body.id
        self.change = change
        self.meta = meta
    }
    
    public init(bodyId: RPBodyId, _ change: RP.Stats, _ meta: [String: RPValue] = [:]) {
        self.body = bodyId
        self.change = change
        self.meta = meta
    }
}
