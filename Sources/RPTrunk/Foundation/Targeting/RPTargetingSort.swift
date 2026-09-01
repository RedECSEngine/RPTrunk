public enum RPTargetingSort<RP: RPSpace>: Equatable {
    case random
    case by([RPTargetingSortDescriptor<RP>])

    public static var anyone: RPTargetingSort { .by([]) }

    public static var highestThreat: RPTargetingSort {
        (try? RPTargetingSort.parse("threat.highest")) ?? .by([])
    }

    public static func parse(_ source: String) throws -> RPTargetingSort {
        let parts = source
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { part -> String in
                var trimmed = part
                while let first = trimmed.first, first.isWhitespace { trimmed.removeFirst() }
                while let last = trimmed.last, last.isWhitespace { trimmed.removeLast() }
                return String(trimmed)
            }
        if parts == ["random"] {
            return .random
        }
        if parts == ["any"] {
            return .by([])
        }
        guard !parts.contains("random"), !parts.contains("any") else {
            throw RPTargetingSortError.mixedSelection(source)
        }
        return .by(try parts.map { try RPTargetingSortDescriptor($0) })
    }

    public func toString() -> String {
        switch self {
        case .random:
            return "random"
        case let .by(descriptors) where descriptors.isEmpty:
            return "any"
        case let .by(descriptors):
            return descriptors.map { $0.toString() }.joined(separator: ", ")
        }
    }
}
