public typealias RPTimeIncrement = Double

public struct RPMoment {
    public let delta: RPTimeIncrement

    public init(delta: RPTimeIncrement) {
        self.delta = delta
    }
}

public protocol RPTemporal {
    associatedtype RP: RPSpace
    var currentTick: RPTimeIncrement { get set }
    var maximumTick: RPTimeIncrement { get }

    mutating func tick(_ moment: RPMoment)
    mutating func resetCooldown()

    func getPendingEvents(in rpSpace: RP) -> [RPEvent<RP>]
}

extension RPTemporal {
    func isCoolingDown() -> Bool {
        currentTick < maximumTick
    }
}
