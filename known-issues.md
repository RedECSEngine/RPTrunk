# Known Issues — RPTrunk

Tracked, diagnosed issues in the RP engine. Maintained per the ecosystem rules
in RedECS/CLAUDE.md: add entries when new issues are diagnosed, and move entries
to the Resolved section (with the fixing commit) when they are addressed. An
issue lives in the repo where its *symptom* is felt.

## Open

### Tests: `testPeriodicStatusEffectEventsAndDecay` is stale and fails
- **Where:** `Tests/RPTrunkTests/StatusEffectsTests.swift:37`.
- **Symptom:** `swift test` is red — one failure, `XCTAssertEqual failed:
  ("0") is not equal to ("1")`. The rest of the suite passes.
- **Cause:** the test builds an effect without a `period`, so it takes
  `RPStatusEffect.defaultPeriod` (1000ms), then ticks `delta: 3` and expects a
  pulse. `RPActiveStatusEffect.getPendingEvents` gates on
  `deltaTick >= statusEffect.period`, so 3 < 1000 yields no event. The test
  predates the configurable `period` field and was written when any accumulated
  delta pulsed; its `delta: 3` is in the older "few ticks" unit while `period`
  is milliseconds.
- **Confirmed pre-existing** (2026-07-22): reproduces on a clean tree with all
  equipment-slot work stashed out.
- **Fix direction:** decide which unit the test means — either tick
  `.init(delta: 3000)`, or construct the effect with `period: 1` to assert the
  old "pulses immediately" intent. Needs Kai's call on the intended semantics,
  so it was left red rather than edited to green.
- **Update (2026-07-31):** still red, and no longer the only one — see the
  global-cooldown entry below.

### Tests: `test_global_cooldown_gates_actions_even_when_the_ability_is_ready` assumes a 500ms GCD
- **Where:** `Tests/RPTrunkTests/BodyTests.swift:67`.
- **Symptom:** `swift test` is red — `XCTAssertFalse failed` at line 87 and
  `XCTAssertEqual failed: ("0") is not equal to ("1")` at line 88.
- **Cause:** the test performs an event, ticks 499 + 1 = 500ms, and expects the
  global cooldown to have elapsed. `RPBody.globalCooldown` defaults to 2500, so
  the body is still cooling down at 500 and offers no pending events. The test
  was written against a 500ms default and never ran — the whole target failed to
  compile from the commit that introduced it (2f0f904) until 2026-07-31.
- **Confirmed pre-existing:** the compile break, and this failure behind it,
  both predate the entity→body rename.
- **Fix direction:** decide which is right — a 2500ms `globalCooldown` default
  with the test ticking 2499 + 1, or a 500ms default. Needs Kai's call on the
  intended pacing, so it was left red rather than edited to green.

## Resolved

### Tests: the target had stopped compiling again at 2f0f904
- **Where:** `Tests/RPTrunkTests/TestGame/TestRPSpace.swift`,
  `BodyTests.swift`, `EquipmentTests.swift`, `ParserTests.swift`.
- **Symptom:** `swift test` failed to build — `TestRPSpace does not conform to
  RPSpace`, `no dynamic member 'getTotalStats'`, `'currentStats' setter is
  inaccessible`.
- **Cause:** 2f0f904 added the `fullyResolvedStats(for stats:)` requirement,
  replaced `getTotalStats()` with `cumulativeWornStats()`, and made
  `currentStats` `private(set)`, without updating the test target.
- **Fixed:** 2026-07-31, mechanically, so the rename could be verified —
  `TestRPSpace` gained an identity `fullyResolvedStats`, `getTotalStats()` call
  sites became `cumulativeWornStats()`, and the direct `currentStats.hp` write
  became `setCurrentStats`. Worth a look: the identity implementation is a
  placeholder, not a considered rule. Commit hash pending.

### Tests: suite stopped compiling after the equipment-slots merge
- **Where:** `Tests/RPTrunkTests/EntityTests.swift` (4 call sites),
  `Tests/RPTrunkTests/EquipmentTests.swift` (2 call sites).
- **Symptom:** `swift test` failed to build — `extra argument 'in' in call` /
  `argument passed to call that takes no arguments`.
- **Cause:** the equipment-slots merge (29ff664) dropped the `in rpSpace`
  parameter from `RPEntity.setCurrentStats` and `getTotalStats` but did not
  update the tests, so the whole suite (including the deliberately-red periodic
  status effect test above) silently stopped running.
- **Fixed:** with the entity global-cooldown change (2026-07-27) — call sites
  mechanically updated to the merged parameterless API; no semantic changes.
  Commit hash pending.
