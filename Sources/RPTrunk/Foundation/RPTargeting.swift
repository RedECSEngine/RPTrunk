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

    public init(_ pool: Pool, _ when: RPConditional<RP> = .always, sort: RPTargetingSort<RP>? = nil) {
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
        let needsValidityChecks = pool != .oneself && pool != .initiator
        let candidates = candidatePool(for: body, in: rpSpace, reactingTo: triggeringEvent)
            .compactMap(rpSpace.bodyById)
            .filter { candidate in
                !needsValidityChecks
                    || candidate.id == bodyId
                    || rpSpace.shouldCheckBodyIsValidTarget(candidate.id, forOtherBodyId: bodyId)
            }
            .filter { candidate in
                (try? when.exec(candidate, initiator: bodyId, rpSpace: rpSpace)) ?? false
            }

        func willTarget(_ candidate: RPBody<RP>) -> Bool {
            !needsValidityChecks
                || candidate.id == bodyId
                || rpSpace.willTargetBody(candidate.id, forOtherBodyId: bodyId)
        }

        guard let sort else {
            return Set(candidates.filter(willTarget).map { $0.id })
        }

        switch sort {
        case .random:
            let ids = candidates.filter(willTarget).map { $0.id }.sorted()
            guard !ids.isEmpty else { return [] }
            return [ids[RP.rollRandom(upperBound: ids.count)]]
        case let .by(descriptors):
            return ranked(candidates, by: descriptors, initiator: bodyId, in: rpSpace)
                .first(where: willTarget)
                .map { [$0.id] } ?? []
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
            return rpSpace.getEnemies(of: body.id).intersection(rpSpace.perceivedBodies(by: body.id))
        case .friendly:
            return rpSpace.getFriends(of: body.id).intersection(rpSpace.perceivedBodies(by: body.id))
        case .all:
            return Set(rpSpace.allBodies()).intersection(rpSpace.perceivedBodies(by: body.id))
        case .oneself:
            return [body.id]
        case .allyTeam:
            let allies = rpSpace.getAllies(of: body.id)
            if let nearbyAlly = allies.intersection(rpSpace.perceivedBodies(by: body.id)).first,
               let teamId = rpSpace.bodyById(nearbyAlly)?.teamId,
               let teamBodies = rpSpace.teamById(teamId)?.bodies
            {
                return teamBodies
            }
            return []
        }
    }

    private func ranked(
        _ candidates: [RPBody<RP>],
        by descriptors: [RPTargetingSortDescriptor<RP>],
        initiator: RPBodyId,
        in rpSpace: RP
    ) -> [RPBody<RP>] {
        candidates.sorted { a, b in
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
        }
    }
}

public extension RPTargeting {
    enum TargetingError: Error {
        case duplicateClause(String)
        case unrecognizedClause(String)
        case unrecognizedPool(String)
    }

    static func fromString(_ query: String) throws -> RPTargeting {
        let text = trimmed(Substring(query))
        guard !text.isEmpty else {
            return RPTargeting(.oneself)
        }

        var markers: [(key: String, keyStart: Substring.Index, valueStart: Substring.Index)] = []
        var index = text.startIndex
        var atWordBoundary = true
        while index < text.endIndex {
            if atWordBoundary, let marker = clauseMarker(in: text, at: index) {
                markers.append((marker.key, index, marker.valueStart))
                index = marker.valueStart
                atWordBoundary = true
                continue
            }
            atWordBoundary = text[index].isWhitespace
            index = text.index(after: index)
        }

        let poolText = trimmed(text[..<(markers.first?.keyStart ?? text.endIndex)])
        var pool = Pool.oneself
        if !poolText.isEmpty {
            guard let parsed = Pool(rawValue: String(poolText)) else {
                throw TargetingError.unrecognizedPool(String(poolText))
            }
            pool = parsed
        }

        var when: RPConditional<RP>?
        var sort: RPTargetingSort<RP>?
        for (offset, marker) in markers.enumerated() {
            let valueEnd = offset + 1 < markers.count ? markers[offset + 1].keyStart : text.endIndex
            let value = String(trimmed(text[marker.valueStart ..< valueEnd]))
            switch marker.key {
            case "when":
                guard when == nil else { throw TargetingError.duplicateClause("when") }
                when = RPConditional(value)
            case "sort":
                guard sort == nil else { throw TargetingError.duplicateClause("sort") }
                sort = try RPTargetingSort.parse(value)
            default:
                throw TargetingError.unrecognizedClause(marker.key)
            }
        }
        return RPTargeting(pool, when ?? .always, sort: sort)
    }

    func toString() -> String {
        var parts: [String] = []
        if pool != .oneself {
            parts.append(pool.rawValue)
        }
        switch when {
        case .always:
            break
        case .never, .custom:
            parts.append("when: \(when.toString())")
        }
        if let sort {
            parts.append("sort: \(sort.toString())")
        }
        return parts.joined(separator: " ")
    }

    private static func clauseMarker(
        in text: Substring,
        at index: Substring.Index
    ) -> (key: String, valueStart: Substring.Index)? {
        var cursor = index
        while cursor < text.endIndex, text[cursor].isLetter {
            cursor = text.index(after: cursor)
        }
        guard cursor > index, cursor < text.endIndex, text[cursor] == ":" else {
            return nil
        }
        return (String(text[index ..< cursor]), text.index(after: cursor))
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
