public protocol Ability {

    var name:String { get }
    var components:[Component] { get }
    var targetType:EventTargetType { get }
}

extension Ability {
    
    public var targetType:EventTargetType {
        for component in components {
            if let t = component.getTargetType() {
                return t
            }
        }
        return .SingleEnemy
    }
    
    public func getStats() -> RPStats {
        return components
            .flatMap { $0.getStats() }
            .reduce(RPStats([:]), combine: +)
    }
}

public struct BasicAbility: Ability {
    public var name:String
    public var components:[Component]
}