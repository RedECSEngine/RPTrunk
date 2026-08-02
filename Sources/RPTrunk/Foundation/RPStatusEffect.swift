
public struct RPStatusEffect<RP: RPSpace>: Codable {
    /// Default time between pulses (ms) when a status effect doesn't specify one.
    public static var defaultPeriod: RPTimeIncrement { 1000 }

    public let code: RPReferenceCode
    public let displayName: String
    public let tags: Set<RPStatusCode>
    public let persistentFragments: [RPFragment<RP>]
    public let persistentStats: RP.Stats
    // both duration and charge can be used or one or the other
    let duration: RPTimeIncrement?
    let charges: Int? // the number of charges left
    /// Time (ms) between periodic pulses of this effect (heal/damage over time).
    let period: RPTimeIncrement
    let ability: RPAbility<RP>?

    public init(
        code: RPReferenceCode,
        displayName: String? = nil,
        tags: Set<RPStatusCode>,
        persistentFragments: [RPFragment<RP>] = [],
        periodicFragments: [RPFragment<RP>] = [],
        duration: Double?,
        charges: Int?,
        period: RPTimeIncrement = RPStatusEffect.defaultPeriod
    ) {
        self.code = code
        self.displayName = displayName ?? code
        self.tags = tags
        self.persistentFragments = persistentFragments
        self.persistentStats = RPFragment(flattenedFrom: persistentFragments).stats ?? .zero
        self.duration = duration
        self.charges = charges
        self.period = period

        if periodicFragments.count > 0 {
            let fragments: [RPFragment<RP>] = periodicFragments + [RPTargeting<RP>(.oneself, .always).toFragment()]
            ability = RPAbility(code: code, displayName: displayName, fragments: fragments, cooldown: nil)
        } else {
            ability = nil
        }
    }

    public func getStatusEffects() -> [RPStatusEffect] {
        [self]
    }

    var totalPulses: Int {
        guard ability != nil, let duration = duration, period > 0 else {
            return 0
        }
        return Int(duration / period)
    }
}

extension RPStatusEffect: Equatable {}

public func ==<Stats: StatsType> (lhs: RPStatusEffect<Stats>, rhs: RPStatusEffect<Stats>) -> Bool {
    lhs.code == rhs.code
        && lhs.tags == rhs.tags
        && lhs.persistentFragments == rhs.persistentFragments
        && lhs.ability == rhs.ability
}
/**
    A Status effect, currently active on an body
 */
public struct RPActiveStatusEffect<RP: RPSpace>: RPTemporal, Codable {
    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement { statusEffect.duration ?? 0 }

    var currentCharge: Int = 0
    public private(set) var pulsesDelivered: Int = 0

    var level: Int? // power level of the buff, if it is stackable

    public var bodyId: RPBodyId
    fileprivate let statusEffect: RPStatusEffect<RP>

    public var code: RPReferenceCode { statusEffect.code }
    public var displayName: String { statusEffect.displayName }
    public var tags: Set<RPStatusCode> { statusEffect.tags }

    public init(
        bodyId: RPBodyId,
        statusEffect: RPStatusEffect<RP>
    ) {
        self.bodyId = bodyId
        self.statusEffect = statusEffect
        currentCharge = statusEffect.charges ?? 0
    }

    public var persistentStats: RP.Stats { statusEffect.persistentStats }

    /// Pulses this effect still owes. An effect with no duration owes them
    /// indefinitely, so this stays at zero for it and expiry never consults it.
    public var remainingPulses: Int {
        Swift.max(0, statusEffect.totalPulses - pulsesDelivered)
    }

    public var isExpired: Bool {
        if statusEffect.charges != nil, currentCharge <= 0 {
            return true
        }
        guard let duration = statusEffect.duration else {
            return false
        }
        return remainingPulses <= 0 && currentTick >= duration
    }

    /// Elapsed time the next pulse is owed at, measured from when the effect was
    /// applied rather than from the last pulse — so a late pulse never pushes the
    /// ones after it later still.
    private var nextPulseDueAt: RPTimeIncrement? {
        guard statusEffect.ability != nil else { return nil }
        return RPTimeIncrement(pulsesDelivered + 1) * statusEffect.period
    }

    public func getPendingEvents(in rpSpace: RP) -> [RPEvent<RP>] {
        guard !isExpired,
              let ability = statusEffect.ability,
              let dueAt = nextPulseDueAt,
              currentTick >= dueAt
        else {
            return []
        }
        return [RPEvent(category: .periodicEffect(name: code), initiator: bodyId, ability: ability, rpSpace: rpSpace)]
    }

    public mutating func tick(_ moment: RPMoment) {
        guard !isExpired else {
            return
        }

        currentTick += moment.delta
    }

    public mutating func didPulse() {
        pulsesDelivered += 1
    }

    public mutating func resetCooldown() {
        currentTick = 0
        pulsesDelivered = 0
    }

    public mutating func expendCharge() {
        currentCharge -= 1
    }
}
