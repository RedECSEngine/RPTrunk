
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
    
    public func getValidTargets(for entity:Entity, in battle: Battle) -> [Entity] {
        
        let validTargets = getValidTargetSet(for: entity, in: battle)
            .filter { possibleTarget in entity.targets.contains(where: { $0 === possibleTarget }) }
            .filter { conditional.exec($0) }
        
        switch type {
        case .oneself, .singleEnemy, .singleFriendly:
            return validTargets.first.map { [$0] } ?? []
        case .random, .randomEnemy, .randomFriendly:
            let randomIndex = Int(arc4random_uniform(UInt32(validTargets.count)))
            return [validTargets[randomIndex]]
        default:
            return validTargets
        }
        
    }
    
    fileprivate func getValidTargetSet(for entity: Entity, in battle: Battle) -> [Entity] {
        switch type {
        case .randomEnemy, .allEnemy, .singleEnemy:
            return battle.getEnemies(of: entity)
        case .randomFriendly, .allFriendly, .singleFriendly:
            return battle.getFriends(of: entity)
        case .all, .random:
            return battle.getEntities()
        case .oneself:
            return [entity]
            
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
