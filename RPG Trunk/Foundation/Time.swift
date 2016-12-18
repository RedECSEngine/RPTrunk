
public struct Moment {
    let parents:[Temporal]
    let delta:Double
    
    public init(delta:Double, parents:[Temporal] = []) {
        self.parents = parents
        self.delta = delta
    }
    
    public func addSibling(_ sibling:Temporal) -> Moment {
        return Moment(delta:self.delta, parents: parents + [sibling])
    }
    
}

public protocol Temporal {
    
    var currentTick:Double { get }
    var maximumTick:Double { get }

    func tick(_ moment:Moment) -> [Event]
    func resetCooldown()
}

extension Temporal {

    func isCoolingDown() -> Bool {
        return currentTick < maximumTick
    }
}
