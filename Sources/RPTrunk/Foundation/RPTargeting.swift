public struct RPTargeting<RP: RPSpace>: Codable {
    public enum Pool: String, CaseIterable {
        case enemy
        case friendly
        case all
        case oneself = "self"
        case initiator
        case allyTeam
    }

    public let pool: Pool
    public let when: RPConditional<RP>
    public let sort: RPTargetingSort<RP>?

    public init(_ pool: Pool, _ when: RPConditional<RP>, sort: RPTargetingSort<RP>? = nil) {
        self.pool = pool
        self.when = when
        self.sort = sort
    }

    private enum CodingKeys: String, CodingKey {
        case rawValue
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self = try RPTargeting.fromString(try values.decode(String.self, forKey: .rawValue))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(toString(), forKey: .rawValue)
    }

    public func getValidTargets(
        for bodyId: RPBodyId,
        in rpSpace: RP,
        reactingTo triggeringEvent: RPEvent<RP>? = nil
    ) -> Set<RPBodyId> {
        guard let body = rpSpace.bodyById(bodyId) else { return [] }
        let candidates = candidatePool(for: body, in: rpSpace, reactingTo: triggeringEvent)
            .compactMap(rpSpace.bodyById)
            .filter { candidate in
                (try? when.exec(candidate, initiator: bodyId, rpSpace: rpSpace)) ?? false
            }

        guard let sort else {
            return Set(candidates.map { $0.id })
        }

        switch sort {
        case .random:
            guard !candidates.isEmpty else { return [] }
            let ids = candidates.map { $0.id }.sorted()
            return [ids[RP.rollRandomIndex(upperBound: ids.count)]]
        case let .by(descriptors):
            return pick(from: candidates, by: descriptors, initiator: bodyId, in: rpSpace)
                .map { [$0] } ?? []
        }
    }

    private func candidatePool(
        for body: RPBody<RP>,
        in rpSpace: RP,
        reactingTo triggeringEvent: RPEvent<RP>?
    ) -> Set<RPBodyId> {
        switch pool {
        case .initiator:
            guard let initiator = triggeringEvent?.initiator, initiator != body.id else {
                return []
            }
            return [initiator]
        case .enemy:
            return rpSpace.getEnemies(of: body.id).intersection(body.targets)
        case .friendly:
            return rpSpace.getFriends(of: body.id).intersection(body.targets)
        case .all:
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

    private func pick(
        from candidates: [RPBody<RP>],
        by descriptors: [RPTargetingSortDescriptor<RP>],
        initiator: RPBodyId,
        in rpSpace: RP
    ) -> RPBodyId? {
        candidates.min { a, b in
            for descriptor in descriptors {
                let valueA = extractValue(
                    RPConditionContext(body: a.id, initiator: initiator),
                    evaluators: descriptor.evaluators,
                    in: rpSpace
                )
                let valueB = extractValue(
                    RPConditionContext(body: b.id, initiator: initiator),
                    evaluators: descriptor.evaluators,
                    in: rpSpace
                )
                switch (valueA, valueB) {
                case (nil, nil):
                    continue
                case (nil, _):
                    return false
                case (_, nil):
                    return true
                case let (lhs?, rhs?):
                    if lhs == rhs { continue }
                    return descriptor.direction == .lowest ? lhs < rhs : rhs < lhs
                }
            }
            return a.id < b.id
        }?.id
    }
}

public extension RPTargeting {
    enum TargetingError: Error {
        case malformedClause(String)
        case duplicateClause(String)
        case unrecognizedClause(String)
        case unrecognizedPool(String)
    }

    static func fromString(_ query: String) throws -> RPTargeting {
        guard !trimmed(Substring(query)).isEmpty else {
            return RPTargeting(.all, .always)
        }
        var clauses: [(key: String, value: String)] = []
        for rawSegment in query.split(separator: ",", omittingEmptySubsequences: false) {
            let segment = trimmed(rawSegment)
            if let colon = segment.firstIndex(of: ":"),
               ["among", "when", "sort"].contains(String(trimmed(segment[..<colon])))
            {
                clauses.append((
                    key: String(trimmed(segment[..<colon])),
                    value: String(trimmed(segment[segment.index(after: colon)...]))
                ))
            } else if clauses.isEmpty {
                throw TargetingError.malformedClause(query)
            } else {
                clauses[clauses.count - 1].value += ", " + segment
            }
        }

        var pool: Pool?
        var when: RPConditional<RP>?
        var sort: RPTargetingSort<RP>?
        for clause in clauses {
            switch clause.key {
            case "among":
                guard pool == nil else { throw TargetingError.duplicateClause("among") }
                guard let parsed = Pool(rawValue: clause.value) else {
                    throw TargetingError.unrecognizedPool(clause.value)
                }
                pool = parsed
            case "when":
                guard when == nil else { throw TargetingError.duplicateClause("when") }
                when = RPConditional(clause.value)
            case "sort":
                guard sort == nil else { throw TargetingError.duplicateClause("sort") }
                sort = try RPTargetingSort.parse(clause.value)
            default:
                throw TargetingError.unrecognizedClause(clause.key)
            }
        }
        return RPTargeting(pool ?? .all, when ?? .always, sort: sort)
    }

    func toString() -> String {
        var parts = ["among: \(pool.rawValue)"]
        switch when {
        case .always:
            break
        case .never, .custom:
            parts.append("when: \(when.toString())")
        }
        if let sort {
            parts.append("sort: \(sort.toString())")
        }
        return parts.joined(separator: ", ")
    }

    private static func trimmed(_ segment: Substring) -> Substring {
        var segment = segment
        while segment.first?.isWhitespace == true { segment.removeFirst() }
        while segment.last?.isWhitespace == true { segment.removeLast() }
        return segment
    }
}

extension RPTargeting: Equatable {}

public func == <RP: RPSpace>(lhs: RPTargeting<RP>, rhs: RPTargeting<RP>) -> Bool {
    lhs.pool == rhs.pool && lhs.when == rhs.when && lhs.sort == rhs.sort
}

extension RPTargeting {
    func toFragment() -> RPFragment<RP> {
        RPFragment<RP>(targetType: self)
    }
}
