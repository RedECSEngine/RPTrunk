@testable import RPTrunk
import XCTest

final class StatusEffectsTests: XCTestCase {
    static var allTests = [
        ("testPeriodicStatusEffectEventsAndDecay", testPeriodicStatusEffectEventsAndDecay),
        ("testOwedPulsesSurviveAnOvershootingFrame", testOwedPulsesSurviveAnOvershootingFrame),
    ]

    var rpSpace: TestRPSpace!
    var body: RPBody<TestRPSpace>!

    override func setUp() {
        body = RPBody<TestRPSpace>(["hp": 30])
        body.id = "abcd"
        rpSpace = TestRPSpace()
        rpSpace.addBody(body)
    }

    private func regen(
        duration: RPTimeIncrement,
        period: RPTimeIncrement
    ) -> RPStatusEffect<TestRPSpace> {
        RPStatusEffect<TestRPSpace>(
            code: "Test",
            tags: [],
            periodicFragments: [
                RPFragment(stats: .init(dict: [\.hp: 1]))
            ],
            duration: duration,
            charges: nil,
            period: period
        )
    }

    /// A three-second regen at a one-second period pulses exactly three times,
    /// each becoming due only as its own moment arrives, and expires spent.
    func testPeriodicStatusEffectEventsAndDecay() {
        var activeSE = RPActiveStatusEffect(
            bodyId: "abcd",
            statusEffect: regen(duration: 3000, period: 1000)
        )

        XCTAssertEqual(activeSE.getPendingEvents(in: rpSpace).count, 0, "nothing is due at t=0")
        XCTAssertFalse(activeSE.isExpired)

        for expectedPulse in 1 ... 3 {
            activeSE.tick(.init(delta: 1000))
            XCTAssertEqual(
                activeSE.getPendingEvents(in: rpSpace).count,
                1,
                "pulse \(expectedPulse) is due at \(expectedPulse * 1000)ms"
            )
            activeSE.didPulse()
            XCTAssertEqual(activeSE.pulsesDelivered, expectedPulse)
            XCTAssertEqual(
                activeSE.getPendingEvents(in: rpSpace).count,
                0,
                "the next pulse isn't due yet"
            )
        }

        XCTAssertEqual(activeSE.remainingPulses, 0)
        XCTAssertTrue(activeSE.isExpired, "duration elapsed and every pulse was delivered")
    }

    /// A frame long enough to skip past the whole duration still owes every
    /// pulse — dropping them would silently shorten a heal-over-time.
    func testOwedPulsesSurviveAnOvershootingFrame() {
        var activeSE = RPActiveStatusEffect(
            bodyId: "abcd",
            statusEffect: regen(duration: 3000, period: 1000)
        )

        activeSE.tick(.init(delta: 5000))

        XCTAssertFalse(activeSE.isExpired, "three pulses are still owed despite the overshoot")
        for _ in 1 ... 3 {
            XCTAssertEqual(activeSE.getPendingEvents(in: rpSpace).count, 1)
            activeSE.didPulse()
        }
        XCTAssertTrue(activeSE.isExpired)
    }
}
