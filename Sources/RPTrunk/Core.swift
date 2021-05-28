
import Foundation

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

public extension Array where Element: Hashable {
    func toSet() -> Set<Element> {
        return Set(self)
    }
}
