
public typealias RPValue = Int

extension Array {

    public func find(finder: (Element) -> Bool) -> Element? {
        
        for element in self {
            if finder(element) {
                return element
            }
        }
        return nil
    }
}