import Foundation

public struct Targeting<RP: RPSpace>: Codable {
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
    public let conditional: Conditional<RP>

    public init(_ type: SelectionType, _ conditional: Conditional<RP>) {
        self.type = type
        self.conditional = conditional
    }

    public func getValidTargets(
        for entity: RPEntityId,
        in rpSpace: RP
    ) -> Set<RPEntityId> {
        guard let entity = rpSpace.entityById(entity) else { return [] }
        let validTargets = getValidTargetSet(for: entity, in: rpSpace)
            .compactMap(rpSpace.entityById)
            .filter { (try? conditional.exec($0, rpSpace: rpSpace)) ?? false }

        switch type {
        case .oneself, .singleEnemy, .singleFriendly:
            return validTargets.first.map { [$0.id] } ?? []
        case .random, .randomEnemy, .randomFriendly:
            let startIndex = validTargets.startIndex
            let randomInt = Int(arc4random_uniform(UInt32(validTargets.count)))
            let randomIndex = validTargets.index(startIndex, offsetBy: randomInt)
            let entity = validTargets[randomIndex]
            return Set([entity.id])
        default:
            return Set(validTargets.map { $0.id })
        }
    }

    fileprivate func getValidTargetSet(
        for entity: RPEntity<RP>,
        in rpSpace: RP
    ) -> Set<RPEntityId> {
        switch type {
        case .randomEnemy, .allEnemy, .singleEnemy:
            return rpSpace.getEnemies(of: entity.id).intersection(entity.targets)
        case .randomFriendly, .allFriendly, .singleFriendly:
            return rpSpace.getFriends(of: entity.id).intersection(entity.targets)
        case .all, .random:
            return Set(rpSpace.allEntities()).intersection(entity.targets)
        case .oneself:
            return [entity.id]
        case .allyTeam:
            let allies = rpSpace.getAllies(of: entity.id)
            if let nearbyAlly = allies.intersection(entity.targets).first,
               let teamId = rpSpace.entityById(nearbyAlly)?.teamId,
               let teamEntities = rpSpace.teamById(teamId)?.entities
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

        let condition: Conditional<RP> = components.count > 1 ? Conditional(components[1]) : .always

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

public func == <RP: RPSpace>(lhs: Targeting<RP>, rhs: Targeting<RP>) -> Bool {
    lhs.type == rhs.type && lhs.conditional == rhs.conditional
}

extension Targeting {
    func toComponent() -> Component<RP> {
        Component<RP>(targetType: self)
    }
}
