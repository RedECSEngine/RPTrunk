public enum RPItemDefinitionStatVariationError: Error, Equatable, Sendable {
    case empty
    case malformed(String)
    case invertedRange(String)
}

public struct RPItemDefinitionStatVariation: Equatable, Sendable {
    public var lowerBound: RPValue
    public var upperBound: RPValue
    public var isRequired: Bool

    public var isFixed: Bool { lowerBound == upperBound }
    public var ceiling: RPValue { upperBound - lowerBound }

    public init(lowerBound: RPValue, upperBound: RPValue, isRequired: Bool) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.isRequired = isRequired
    }

    public init(parsing cell: String) throws {
        var text = Self.trimmed(Substring(cell))
        var isRequired = true
        if text.hasSuffix("?") {
            isRequired = false
            text = Self.trimmed(text.dropLast())
        }
        guard !text.isEmpty else { throw RPItemDefinitionStatVariationError.empty }

        guard let separator = text.dropFirst().firstIndex(of: "-") else {
            guard let value = RPValue(text) else {
                throw RPItemDefinitionStatVariationError.malformed(cell)
            }
            self.init(lowerBound: value, upperBound: value, isRequired: isRequired)
            return
        }

        let lowerText = Self.trimmed(text[text.startIndex ..< separator])
        let upperText = Self.trimmed(text[text.index(after: separator)...])
        guard let lower = RPValue(lowerText), let upper = RPValue(upperText) else {
            throw RPItemDefinitionStatVariationError.malformed(cell)
        }
        guard lower <= upper else {
            throw RPItemDefinitionStatVariationError.invertedRange(cell)
        }
        self.init(lowerBound: lower, upperBound: upper, isRequired: isRequired)
    }

    private static let whitespace: Set<Character> = [" ", "\t", "\n", "\r", "\r\n"]

    private static func trimmed(_ value: Substring) -> Substring {
        var slice = value
        while let first = slice.first, whitespace.contains(first) { slice = slice.dropFirst() }
        while let last = slice.last, whitespace.contains(last) { slice = slice.dropLast() }
        return slice
    }
}
