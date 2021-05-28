import Foundation

public struct Targeting: Codable {
    public enum SelectionType: String, Codable {
        case oneself
        case random
        case all
        case singleEnemy
        case allEnemy
        case randomEnemy
        case singleFriendly
        case allFriendly
        case randomFriendly
        case allyTeam
    }

    public let type: SelectionType
    public let conditional: Conditional

    public init(_ type: SelectionType, _ conditional: Conditional) {
        self.type = type
        self.conditional = conditional
    }

    public func getValidTargets(for entity: Entity, in rpSpace: RPSpace) -> Set<Entity> {
        let validTargets = getValidTargetSet(for: entity, in: rpSpace)
            .filter { conditional.exec($0) }

        switch type {
        case .oneself, .singleEnemy, .singleFriendly:
            return validTargets.first.map { [$0] } ?? []
        case .random, .randomEnemy, .randomFriendly:
            let startIndex = validTargets.startIndex
            let randomInt = Int(arc4random_uniform(UInt32(validTargets.count)))
            let randomIndex = validTargets.index(startIndex, offsetBy: randomInt)
            let entity = validTargets[randomIndex]
            return Set([entity])
        default:
            return Set(validTargets)
        }
    }

    fileprivate func getValidTargetSet(for entity: Entity, in rpSpace: RPSpace) -> Set<Entity> {
        switch type {
        case .randomEnemy, .allEnemy, .singleEnemy:
            return rpSpace.getEnemies(of: entity).intersection(entity.targets)
        case .randomFriendly, .allFriendly, .singleFriendly:
            return rpSpace.getFriends(of: entity).intersection(entity.targets)
        case .all, .random:
            return rpSpace.getEntities().intersection(entity.targets)
        case .oneself:
            return [entity]
        case .allyTeam:
            let allies = rpSpace.getAllies(of: entity)
            if let nearbyAlly = allies.intersection(entity.targets).first,
               let teamId = nearbyAlly.teamId,
               let teamEntities = rpSpace.teams[teamId]?.entities
            {
                return teamEntities
            }
            return []
        }
    }
}

public extension Targeting {
    static func fromString(_ query: String) -> Targeting {
        let components = query.components(separatedBy: ":")
        guard let type = components.first else {
            fatalError("Unexpected format for string translation to target")
        }

        let condition: Conditional = components.count > 1 ? Conditional(components[1]) : .always

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
        case "allyTeam":
            return Targeting(.allyTeam, condition)
        default:
            return Targeting(.all, condition) // type would be the condition in this case
        }
    }
}

extension Targeting: Equatable {}

public func == (lhs: Targeting, rhs: Targeting) -> Bool {
    lhs.type == rhs.type && lhs.conditional == rhs.conditional
}

extension Targeting {
    func toComponent() -> Component {
        Component(targetType: self)
    }
}
