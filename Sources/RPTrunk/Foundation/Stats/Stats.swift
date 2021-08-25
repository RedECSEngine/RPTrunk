//public struct Stats: Codable {
//    public static let empty = Stats([:])
//
//    fileprivate let values: [String: RPValue]
//
//    public init(_ data: [String: RPValue], asPartial: Bool = false) {
//        var stats: [String: RPValue] = [:]
//        for type in RPGameEnvironment.statTypes {
//            stats[type] = data[type] ?? (asPartial ? nil : 0) // either set it, initialize to 0 or set as nil, if asP
//        }
//        values = stats
//    }
//
//    public subscript(index: String) -> RPValue {
//        values[index] ?? 0
//    }
//
//    public func get(_ key: String) -> RPValue? {
//        values[key]
//    }
//
//    public func getStats() -> Stats? {
//        self
//    }
//}
////
////extension Stats: Sequence {
////    public func makeIterator() -> DictionaryIterator<String, RPValue> {
////        values.makeIterator()
////    }
////}
//
//extension Stats: ExpressibleByDictionaryLiteral {
//    public init(dictionaryLiteral elements: (String, RPValue)...) {
//        values = Dictionary(uniqueKeysWithValues: elements)
//    }
//}
//
//extension Stats: Comparable {}
//
//public func == (a: Stats, b: Stats) -> Bool {
//    for type in RPGameEnvironment.statTypes where a[type] != b[type] {
//        return false
//    }
//    return true
//}
//
//public func < (a: Stats, b: Stats) -> Bool {
//    for (type, value) in b.values where a[type] < value {
//        return true
//    }
//
//    return false
//}
//
//// MARK: Other math functions
//
//public func + (a: Stats, b: Stats) -> Stats {
//    var dict: [String: RPValue] = a.values
//    for (type, val) in b.values {
//        dict[type] = a[type] + val
//    }
//    return Stats(dict)
//}
//
//public func - (a: Stats, b: Stats) -> Stats {
//    var dict: [String: RPValue] = [:]
//    for (type, val) in b.values {
//        dict[type] = a[type] - val
//    }
//    return Stats(dict)
//}
//
//public func * (a: Stats, b: Stats) -> Stats {
//    var dict: [String: RPValue] = [:]
//    for (type, val) in b.values {
//        dict[type] = a[type] * val
//    }
//    return Stats(dict)
//}
//
//public func * (a: Stats, amount: Int) -> Stats {
//    var dict: [String: RPValue] = [:]
//    for (type, val) in a.values {
//        dict[type] = val * amount
//    }
//    return Stats(dict)
//}
