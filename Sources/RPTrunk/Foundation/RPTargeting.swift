public struct RPTargeting<RP: RPSpace>: Codable {
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
    public let conditional: RPConditional<RP>

    public init(_ type: SelectionType, _ conditional: RPConditional<RP>) {
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
        case .singleEnemy:
            let chosen = validTargets.min { a, b in
                let threatA = entity.threat[a.id] ?? 0
                let threatB = entity.threat[b.id] ?? 0
                return threatA != threatB ? threatA > threatB : a.id < b.id
            }
            return chosen.map { [$0.id] } ?? []
        case .oneself, .singleFriendly:
            return validTargets.min { $0.id < $1.id }.map { [$0.id] } ?? []
        case .random, .randomEnemy, .randomFriendly:
            let startIndex = validTargets.startIndex
            let randomInt = Int.random(in: 0..<validTargets.count)
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

public extension RPTargeting {
    static func fromString(_ query: String) -> RPTargeting {
        let parts = query.split(separator: ":", omittingEmptySubsequences: false)
        guard let type = parts.first.map(String.init) else {
            fatalError("Unexpected format for string translation to target")
        }

        let condition: RPConditional<RP> = parts.count > 1 ? RPConditional(String(parts[1])) : .always

        switch type {
        case "self":
            return RPTargeting(.oneself, condition)
        case "enemy":
            return RPTargeting(.singleEnemy, condition)
        case "all":
            return RPTargeting(.all, condition)
        case "random":
            return RPTargeting(.random, condition)
        case "allFriendlies":
            return RPTargeting(.allFriendly, condition)
        case "allEnemies":
            return RPTargeting(.allEnemy, condition)
        case "ally", "singleFriendly":
            return RPTargeting(.singleFriendly, condition)
        case "randomFriendly":
            return RPTargeting(.randomFriendly, condition)
        case "randomEnemy":
            return RPTargeting(.randomEnemy, condition)
        case "allyTeam":
            return RPTargeting(.allyTeam, condition)
        default:
            return RPTargeting(.all, condition) // type would be the condition in this case
        }
    }
}

extension RPTargeting: Equatable {}

public func == <RP: RPSpace>(lhs: RPTargeting<RP>, rhs: RPTargeting<RP>) -> Bool {
    lhs.type == rhs.type && lhs.conditional == rhs.conditional
}

extension RPTargeting {
    func toFragment() -> RPFragment<RP> {
        RPFragment<RP>(targetType: self)
    }
}
