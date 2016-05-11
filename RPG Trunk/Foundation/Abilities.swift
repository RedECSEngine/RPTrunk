
public protocol Ability {

    var name:String { get }
    var components:[Component] { get }
    
    var stats:RPStats { get }
    var cost:RPStats { get }
    var targetType:EventTargetType { get }
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
    
    public var targetType:EventTargetType {
        return combineComponentTargetTypes(components)
    }
    
    public var stats: RPStats {
        return combineComponentStats(components)
    }
    
    public var cost:RPStats {
        return combineComponentCosts(components)
    }
}

public struct CostlessAbility: Ability {
    public var name:String
    public var components:[Component]
    
    public init(name:String,components:[Component], shouldUseDefaults:Bool = true) {
        self.name = name
        self.components = components
        if shouldUseDefaults {
            self.components += RPGameEnvironment.current.delegate.abilityDefaults
        }
    }
    
    public var targetType:EventTargetType {
        return combineComponentTargetTypes(components)
    }
    
    public var stats: RPStats {
        return combineComponentStats(components)
    }
    
    public var cost:RPStats {
        return RPStats()
    }
}