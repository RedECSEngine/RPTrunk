
import Foundation

public typealias RPValue = Int

extension Array {
    public func toDictionary(_ transform: (Element) -> String) -> [String: Element] {
        let emptyDict = [String: Element]()
        
        return reduce(emptyDict) { (prev, elem) -> [String: Element] in
            var new = prev
            new[transform(elem)] = elem
            return new
        }
    }
}
