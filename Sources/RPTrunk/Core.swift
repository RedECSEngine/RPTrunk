public typealias RPValue = Int

public extension Array {
    func toDictionary(_ transform: (Element) -> String) -> [String: Element] {
        let emptyDict = [String: Element]()

        return reduce(emptyDict) { prev, elem -> [String: Element] in
            var new = prev
            new[transform(elem)] = elem
            return new
        }
    }
}

#if canImport(UIKit) || canImport(AppKit)
import Foundation
typealias UUID = Foundation.UUID
#else
struct UUID { // TODO: Fix this
    private var stringValue: String = "\(Int.random(in: 0...Int.max))"
    var uuidString: String {
        return stringValue
    }
}
#endif
