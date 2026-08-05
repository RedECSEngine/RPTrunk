public struct RPTriggerCandidate<RP: RPSpace> {
    public let owner: RPBodyId
    public let source: RPTriggerSource
    public let trigger: RPTrigger<RP>
    public let event: RPEvent<RP>

    public init(
        owner: RPBodyId,
        source: RPTriggerSource,
        trigger: RPTrigger<RP>,
        event: RPEvent<RP>
    ) {
        self.owner = owner
        self.source = source
        self.trigger = trigger
        self.event = event
    }
}
