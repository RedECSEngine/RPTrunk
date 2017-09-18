
public struct Targeting: Component {

    public enum SelectionType {
        
        case oneself
        case random
        case all
        case singleEnemy
        case allEnemy
        case randomEnemy
        case singleFriendly
        case allFriendly
        case randomFriendly
    }

    public let type:SelectionType
    public let conditional:Conditional
    
    public init(_ type:SelectionType, _ conditional:Conditional) {
        self.type = type
        self.conditional = conditional
    }
    
    public func validTargets(_ potentialTargets:[Entity], forEntity entity:Entity) -> [Entity] {
        
        let validTargets = potentialTargets.filter { isValid($0, forEntity: entity) }
        
        guard let first = validTargets.first else {
            return validTargets
        }
        
        switch type {
        case .oneself, .singleEnemy, .singleFriendly:
            return [first]
        case .random, .randomEnemy, .randomFriendly:
            let randomIndex = Int(arc4random_uniform(UInt32(validTargets.count)))
            return [validTargets[randomIndex]]
        default:
        return validTargets
        }
        
    }
    
    public func isValid(_ potentialTarget:Entity, forEntity entity:Entity) -> Bool {
        
        switch type {
        case .all:
            return conditional.exec(potentialTarget)
        case .random:
            return conditional.exec(potentialTarget)
        case .oneself:
            return potentialTarget === entity && conditional.exec(potentialTarget)
        default:
            //TODO: Make cases for enemy/friendly types
            return false
        }
    }
}

extension Targeting {
    
    public static func fromString(_ query:String) -> Targeting {
        
        let components = query.components(separatedBy: ":")
        guard let type = components.first else {
            fatalError("Unexpected format for string translation to target")
        }
        
        let condition:Conditional = components.count > 1 ? Conditional(components[1]) : .always
        
        switch type {
            
        case "self":
            return Targeting(.oneself, condition)
        case "enemy":
            return Targeting(.singleEnemy, condition)
        case "all":
            return Targeting(.all, condition)
        case "random":
            return Targeting(.random, condition)
        case "allFriendlies":
            return Targeting(.allFriendly, condition)
        case "allEnemies":
            return Targeting(.allEnemy, condition)
        case "ally":
            return Targeting(.singleFriendly, condition)
        case "randomFriendly":
            return Targeting(.randomFriendly, condition)
        case "randomEnemy":
            return Targeting(.randomEnemy, condition)
        default:
            return Targeting(.all, condition) //type would be the condition in this case
            
        }
    }
}

extension Targeting: Equatable {}

public func ==(lhs:Targeting, rhs:Targeting) -> Bool {
    return lhs.type == rhs.type && lhs.conditional == rhs.conditional
}
