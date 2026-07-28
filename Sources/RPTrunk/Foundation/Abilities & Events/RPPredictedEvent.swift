public struct RPPredictedEvent<RP: RPSpace>: Equatable, Codable {
    public let event: RPEvent<RP>
    public let readyIn: RPTimeIncrement

    public init(event: RPEvent<RP>, readyIn: RPTimeIncrement) {
        self.event = event
        self.readyIn = readyIn
    }
}
