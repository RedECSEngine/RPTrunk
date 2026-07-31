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
        for body: RPBodyId,
        in rpSpace: RP
    ) -> Set<RPBodyId> {
        guard let body = rpSpace.bodyById(body) else { return [] }
        let validTargets = getValidTargetSet(for: body, in: rpSpace)
            .compactMap(rpSpace.bodyById)
            .filter { (try? conditional.exec($0, rpSpace: rpSpace)) ?? false }

        switch type {
        case .singleEnemy:
            let chosen = validTargets.min { a, b in
                let threatA = body.threat[a.id] ?? 0
                let threatB = body.threat[b.id] ?? 0
                return threatA != threatB ? threatA > threatB : a.id < b.id
            }
            return chosen.map { [$0.id] } ?? []
        case .oneself, .singleFriendly:
            return validTargets.min { $0.id < $1.id }.map { [$0.id] } ?? []
        case .random, .randomEnemy, .randomFriendly:
            let startIndex = validTargets.startIndex
            let randomInt = Int.random(in: 0..<validTargets.count)
            let randomIndex = validTargets.index(startIndex, offsetBy: randomInt)
            let body = validTargets[randomIndex]
            return Set([body.id])
        default:
            return Set(validTargets.map { $0.id })
        }
    }

    fileprivate func getValidTargetSet(
        for body: RPBody<RP>,
        in rpSpace: RP
    ) -> Set<RPBodyId> {
        switch type {
        case .randomEnemy, .allEnemy, .singleEnemy:
            return rpSpace.getEnemies(of: body.id).intersection(body.targets)
        case .randomFriendly, .allFriendly, .singleFriendly:
            return rpSpace.getFriends(of: body.id).intersection(body.targets)
        case .all, .random:
            return Set(rpSpace.allBodies()).intersection(body.targets)
        case .oneself:
            return [body.id]
        case .allyTeam:
            let allies = rpSpace.getAllies(of: body.id)
            if let nearbyAlly = allies.intersection(body.targets).first,
               let teamId = rpSpace.bodyById(nearbyAlly)?.teamId,
               let teamBodies = rpSpace.teamById(teamId)?.bodies
            {
                return teamBodies
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
