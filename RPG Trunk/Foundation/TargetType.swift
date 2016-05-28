
public enum TargetType: Component {
    
    case Oneself(Conditional)
    case Random(Conditional)
    case All(Conditional)
    
    case SingleEnemy(Conditional)
    case AllEnemy(Conditional)
    case RandomEnemy(Conditional)
    case SingleFriendly(Conditional)
    case AllFriendly(Conditional)
    case RandomFriendly(Conditional)
    
    public func getTargetType() -> TargetType? {
        return self
    }
    
    public func validTargets(potentialTargets:[Entity], forEntity entity:Entity) -> [Entity] {
        
        let validTargets = potentialTargets.filter { isValid($0, forEntity: entity) }
        
        guard let first = validTargets.first else {
            return validTargets
        }
        
        switch self {
        case .Oneself, .SingleEnemy, .SingleFriendly:
            return [first]
        case .Random, .RandomEnemy, .RandomFriendly:
            return [validTargets.shuffle().first!]
        default:
        return validTargets
        }
        
    }
    
    public func isValid(potentialTarget:Entity, forEntity entity:Entity) -> Bool {
        
        switch self {
        case .All(let conditional):
            return conditional.exec(potentialTarget)
        case .Random(let conditional):
            return conditional.exec(potentialTarget)
        case .Oneself(let conditional):
            return potentialTarget === entity && conditional.exec(potentialTarget)
        default:
            //TODO: Make cases for enemy/friendly types
            return false
        }
    }

}

extension TargetType {
    
    public static func fromString(query:String) -> TargetType {
        
        let components = query.componentsSeparatedByString(":")
        guard let type = components.first else {
            fatalError("Unexpected format for string translation to target")
        }
        
        let condition:Conditional = components.count > 1 ? Conditional(components[1]) : .Always
        
        switch type {
            
        case "self":
            return .Oneself(condition)
        case "enemy":
            return .SingleEnemy(condition)
        case "all":
            return .All(condition)
        case "random":
            return .Random(condition)
        case "allFriendlies":
            return .AllFriendly(condition)
        case "allEnemies":
            return .AllEnemy(condition)
        case "ally":
            return .SingleFriendly(condition)
        case "randomFriendly":
            return .RandomFriendly(condition)
        case "randomEnemy":
            return .RandomEnemy(condition)
        default:
            return .All(Conditional(type)) //type would be the condition in this case
            
        }
    }
    
}

extension TargetType:Equatable { }

public func == (lhs:TargetType, rhs:TargetType) -> Bool {
    
    switch (lhs, rhs) {
    case (.All, .All): return true
    case (.Oneself, .Oneself): return true
    case (.Random, .Random): return true
    case (.SingleEnemy, .SingleEnemy): return true
    case (.SingleFriendly, .SingleFriendly): return true
    case (.AllEnemy, .AllEnemy): return true
    case (.AllFriendly, .AllFriendly): return true
    case (.RandomEnemy, .RandomEnemy): return true
    case (.RandomFriendly, .RandomFriendly): return true
        
    default:
        return false
    }

}