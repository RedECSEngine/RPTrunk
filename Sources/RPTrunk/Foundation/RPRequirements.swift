public enum RPStatusRequirement: Equatable, Codable, Hashable {
    case with(RPStatusCode)
    case without(RPStatusCode)

    public var code: RPStatusCode {
        switch self {
        case .with(let code), .without(let code):
            return code
        }
    }

    public init(_ query: String) {
        if query.hasPrefix("!") {
            self = .without(RPStatusCode(String(query.dropFirst())))
        } else {
            self = .with(RPStatusCode(query))
        }
    }

    public func isSatisfied<RP: RPSpace>(by body: RPBody<RP>) -> Bool {
        switch self {
        case .with(let code):
            return body.hasStatus(code)
        case .without(let code):
            return !body.hasStatus(code)
        }
    }
}

extension RPStatusRequirement: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

public struct RPThreatRequirement: Equatable, Codable {
    public var minimum: RPValue?
    public var maximum: RPValue?

    public init(minimum: RPValue? = nil, maximum: RPValue? = nil) {
        self.minimum = minimum
        self.maximum = maximum
    }

    public func isSatisfied<RP: RPSpace>(against bodyId: RPBodyId, in rpSpace: RP) -> Bool {
        let threats = rpSpace.threatsAgainst(bodyId)
        if let maximum, threats.contains(where: { $0 > maximum }) {
            return false
        }
        if let minimum, !threats.contains(where: { $0 >= minimum }) {
            return false
        }
        return true
    }
}
