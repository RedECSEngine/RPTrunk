
public struct Targeting {

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
    
    public func getValidTargets(for entity:Entity, in rpSpace: RPSpace) -> [Entity] {
        
        let validTargets = getValidTargetSet(for: entity, in: rpSpace)
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
    
    fileprivate func getValidTargetSet(for entity: Entity, in rpSpace: RPSpace) -> [Entity] {
        switch type {
        case .randomEnemy, .allEnemy, .singleEnemy:
            return rpSpace.getEnemies(of: entity)
        case .randomFriendly, .allFriendly, .singleFriendly:
            return rpSpace.getFriends(of: entity)
        case .all, .random:
            return rpSpace.getEntities()
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
        case "ally", "singleFriendly":
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

extension Targeting: Component {
    
    public func getTargeting() -> Targeting? {
        return self
    }
    
    public func getStats() -> Stats? {
        return nil
    }
    
    public func getCost() -> Stats? {
        return nil
    }
    
    public func getRequirements() -> Stats? {
        return nil
    }
    
    public func getDischargedStatusEffects() -> [String] {
        return []
    }
    
    public func getStatusEffects() -> [StatusEffect] {
        return []
    }
    
    public func getItemExchange() -> ItemExchange? {
        return nil
    }
}
