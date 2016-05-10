
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
        return combineComponentStats(components)
    }
    
    public var cost:RPStats {
        return combineComponentCosts(components)
    }
}

public struct BasicAbility: Ability {
    public var name:String
    public var components:[Component]
    
    public init(name:String,components:[Component], shouldUseDefaults:Bool = true) {
        self.name = name
        self.components = components
        if shouldUseDefaults {
            self.components += RPGameEnvironment.current.delegate.abilityDefaults
        }
    }
}