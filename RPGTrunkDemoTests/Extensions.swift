import Foundation
import UIKit
import RPTrunk

/*
extension Entity: CustomStringConvertible {
    public var description: String {
        return "An Entity"
    }
}
*/

extension Entity: CustomPlaygroundQuickLookable {
    public func customPlaygroundQuickLook() -> PlaygroundQuickLook {
        return PlaygroundQuickLook(reflecting: EntityQuickLookView(entity: self))
    }
}

public class EntityQuickLookView: UIView {
    public init(entity:Entity) {
        super.init(frame: CGRectMake(0, 0, 100, 200))
        self.backgroundColor = UIColor.whiteColor()
        let hpLabel = UILabel(frame: CGRectMake(0,0, 100, 20))
        hpLabel.text = "hp: \(entity["hp"])"
        self.addSubview(hpLabel)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}