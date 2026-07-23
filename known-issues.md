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
