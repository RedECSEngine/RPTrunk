public struct RPConditionContext {
    public let body: RPBodyId
    public let initiator: RPBodyId

    public init(body: RPBodyId, initiator: RPBodyId) {
        self.body = body
        self.initiator = initiator
    }
}
