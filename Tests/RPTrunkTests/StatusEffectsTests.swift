@testable import RPTrunk
import XCTest

final class StatusEffectsTests: XCTestCase {
    static var allTests = [
        ("testPeriodicStatusEffectEventsAndDecay", testPeriodicStatusEffectEventsAndDecay),
    ]
    
    var rpSpace: TestRPSpace!
    var body: RPBody<TestRPSpace>!

    override func setUp() {
        body = RPBody<TestRPSpace>(["hp": 30])
        body.id = "abcd"
        rpSpace = TestRPSpace()
        rpSpace.addBody(body)
    }

    func testPeriodicStatusEffectEventsAndDecay() {
        let se = RPStatusEffect<TestRPSpace>(
            code: "Test",
            tags: [],
            fragments: [
                RPFragment(stats: .init(dict: [\.hp: 1]))
            ],
            duration: 2,
            charges: nil
        )
        var activeSE = RPActiveStatusEffect(bodyId: "abcd", statusEffect: se)

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
