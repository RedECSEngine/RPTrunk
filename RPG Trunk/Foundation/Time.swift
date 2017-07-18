public typealias RPTimeIncrement = Double

public struct Moment {
    let parents:[Temporal]
    let delta:RPTimeIncrement
    
    public init(delta:RPTimeIncrement, parents:[Temporal] = []) {
        self.parents = parents
        self.delta = delta
    }
    
    public func addSibling(_ sibling:Temporal) -> Moment {
        return Moment(delta:self.delta, parents: parents + [sibling])
    }
    
}

public protocol Temporal {
    
    var currentTick:RPTimeIncrement { get }
    var maximumTick:RPTimeIncrement { get }

    mutating func tick(_ moment:Moment) -> [Event]
    mutating func resetCooldown()
}

extension Temporal {

    func isCoolingDown() -> Bool {
        return currentTick < maximumTick
    }
}
