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

    public var customPlaygroundQuickLook: PlaygroundQuickLook {
        return PlaygroundQuickLook(reflecting: EntityQuickLookView(entity: self))
    }
}

open class EntityQuickLookView: UIView {
    public init(entity:Entity) {
        super.init(frame: CGRect(x: 0, y:0, width: 100, height: 200))
        self.backgroundColor = UIColor.white
        let hpLabel = UILabel(frame: CGRect(x: 0, y:0, width: 100, height: 20))
        hpLabel.text = "hp: \(entity["hp"])"
        self.addSubview(hpLabel)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
