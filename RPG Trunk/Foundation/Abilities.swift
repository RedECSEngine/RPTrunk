public protocol Ability {

    var name:String { get }
    var components:[Component] { get }
}

extension Ability {
    public func getStats() -> RPStats {
        return components
            .flatMap { $0.getStats() }
            .reduce(RPStats([:])) { $0 + $1 }
    }
}

public struct BasicAbility: Ability {
    public var name:String
    public var components:[Component]
    public var targetType:EventTargetType = .Oneself  // RPGEventTargetType
}