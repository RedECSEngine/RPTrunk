public typealias RPTimeIncrement = Double

public struct Moment {
    let parents: [Temporal]
    let delta: RPTimeIncrement

    public init(delta: RPTimeIncrement, parents: [Temporal] = []) {
        self.parents = parents
        self.delta = delta
    }

    public func addSibling(_ sibling: Temporal) -> Moment {
        return Moment(delta: delta, parents: parents + [sibling])
    }
}

public protocol Temporal {
    var currentTick: RPTimeIncrement { get set }
    var maximumTick: RPTimeIncrement { get }

    mutating func tick(_ moment: Moment)
    mutating func resetCooldown()

    func getPendingEvents(in rpSpace: RPSpace) -> [Event]
}

extension Temporal {
    func isCoolingDown() -> Bool {
        return currentTick < maximumTick
    }
}
