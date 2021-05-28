@testable import RPTrunk
import XCTest

final class StatusEffectsTests: XCTestCase {
    static var allTests = [
        ("testCooldown", testCooldown),
    ]

    func testCooldown() {
        let se = StatusEffect(identity: "Test", components: [], duration: nil, charges: 1)
        let activeSE = ActiveStatusEffect(entityId: "", statusEffect: se)

        XCTAssertEqual(activeSE.isCoolingDown(), true)
    }
}
