
public struct Targeting: Component {

    public enum SelectionType {
        
        case Oneself
        case Random
        case All
        case SingleEnemy
        case AllEnemy
        case RandomEnemy
        case SingleFriendly
        case AllFriendly
        case RandomFriendly
    }

    public let type:SelectionType
    public let conditional:Conditional
    
    public init(_ type:SelectionType, _ conditional:Conditional) {
        self.type = type
        self.conditional = conditional
    }
    
    public func validTargets(potentialTargets:[Entity], forEntity entity:Entity) -> [Entity] {
        
        let validTargets = potentialTargets.filter { isValid($0, forEntity: entity) }
        
        guard let first = validTargets.first else {
            return validTargets
        }
        
        switch type {
        case .Oneself, .SingleEnemy, .SingleFriendly:
            return [first]
        case .Random, .RandomEnemy, .RandomFriendly:
            return [validTargets.shuffle().first!]
        default:
        return validTargets
        }
        
    }
    
    public func isValid(potentialTarget:Entity, forEntity entity:Entity) -> Bool {
        
        switch type {
        case .All:
            return conditional.exec(potentialTarget)
        case .Random:
            return conditional.exec(potentialTarget)
        case .Oneself:
            return potentialTarget === entity && conditional.exec(potentialTarget)
        default:
            //TODO: Make cases for enemy/friendly types
            return false
        }
    }
}

extension Targeting {
    
    public static func fromString(query:String) -> Targeting {
        
        let components = query.componentsSeparatedByString(":")
        guard let type = components.first else {
            fatalError("Unexpected format for string translation to target")
        }
        
        let condition:Conditional = components.count > 1 ? Conditional(components[1]) : .Always
        
        switch type {
            
        case "self":
            return Targeting(.Oneself, condition)
        case "enemy":
            return Targeting(.SingleEnemy, condition)
        case "all":
            return Targeting(.All, condition)
        case "random":
            return Targeting(.Random, condition)
        case "allFriendlies":
            return Targeting(.AllFriendly, condition)
        case "allEnemies":
            return Targeting(.AllEnemy, condition)
        case "ally":
            return Targeting(.SingleFriendly, condition)
        case "randomFriendly":
            return Targeting(.RandomFriendly, condition)
        case "randomEnemy":
            return Targeting(.RandomEnemy, condition)
        default:
            return Targeting(.All, condition) //type would be the condition in this case
            
        }
    }
}

extension Targeting: Equatable {}

public func ==(lhs:Targeting, rhs:Targeting) -> Bool {
    return lhs.type == rhs.type && lhs.conditional == rhs.conditional
}
