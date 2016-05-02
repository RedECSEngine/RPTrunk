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
    
    public var stats: RPStats {
        return components
            .flatMap { $0.getStats() }
            .reduce(RPStats([:]), combine: +)
    }
    
    public var cost:RPStats {
        return self.components.reduce(RPStats()) {
            prev, current in
            guard let c = current.getCost() else {
                return prev
            }
            return prev + c
        }
    }
}

public struct BasicAbility: Ability {
    public var name:String
    public var components:[Component]
    
    public init(name:String,components:[Component]) {
        self.name = name
        self.components = components
    }
}