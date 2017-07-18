
import Foundation

public typealias RPValue = Int

extension Collection {
    /// Return a copy of `self` with its elements shuffled
    func shuffle() -> [Iterator.Element] {
        var list = Array(self)
        list.shuffleInPlace()
        return list
    }
}

extension MutableCollection where Index == Int, IndexDistance == Int {
    /// Shuffle the elements of `self` in-place.
    mutating func shuffleInPlace() {
        // empty and single-element collections don't shuffle
        if count < 2 { return }
        
        for i in 0..<(count - 1) {
            let j = Int(arc4random_uniform(UInt32(count - i))) + i
            guard i != j else { continue }
            self.swapAt(i, j)
        }
    }
}

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
