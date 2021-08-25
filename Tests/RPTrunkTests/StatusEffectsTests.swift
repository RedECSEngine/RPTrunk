@testable import RPTrunk
import XCTest

final class StatusEffectsTests: XCTestCase {
    static var allTests = [
        ("testPeriodicStatusEffectEventsAndDecay", testPeriodicStatusEffectEventsAndDecay),
    ]
    
    var rpSpace: TestRPSpace!
    var entity: RPEntity<TestRPSpace>!

    override func setUp() {
        entity = RPEntity<TestRPSpace>(["hp": 30])
        entity.id = "abcd"
        rpSpace = TestRPSpace()
        rpSpace.addEntity(entity)
    }

    func testPeriodicStatusEffectEventsAndDecay() {
        let se = StatusEffect<TestRPSpace>(
            name: "Test",
            tags: [],
            components: [
                Component(stats: .init(dict: [\.hp: 1]))
            ],
            duration: 2,
            charges: nil
        )
        var activeSE = ActiveStatusEffect(entityId: "abcd", statusEffect: se)

        XCTAssertEqual(activeSE.isCoolingDown(), true)
        XCTAssertEqual(activeSE.getPendingEvents(in: rpSpace).count, 0)
        XCTAssertEqual(activeSE.currentTick, 0)
        XCTAssertEqual(activeSE.isCoolingDown(), true)
        
        activeSE.tick(.init(delta: 3))
        XCTAssertEqual(activeSE.getPendingEvents(in: rpSpace).count, 1)
        XCTAssertEqual(activeSE.currentTick, 0)
        XCTAssertEqual(activeSE.isCoolingDown(), true)
        
        activeSE.incrementTick()
        XCTAssertEqual(activeSE.getPendingEvents(in: rpSpace).count, 0)
        XCTAssertEqual(activeSE.currentTick, 1)
        XCTAssertEqual(activeSE.isCoolingDown(), true)
        
        activeSE.incrementTick()
        XCTAssertEqual(activeSE.currentTick, 2)
        XCTAssertEqual(activeSE.isCoolingDown(), false)
    }
}
