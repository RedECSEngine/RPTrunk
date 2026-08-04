public enum RPChance {
    public static let certain: RPValue = 10000
}

public enum RPTriggerSource: Codable, Equatable, Hashable {
    case body
    case statusEffect(RPReferenceCode)
}

public struct RPTrigger<RP: RPSpace>: Codable, Equatable {
    public enum TriggerType: String, Codable {
        case postEvent
        case postEventInitiated
        case postEventTargeted
    }

    public let code: RPReferenceCode
    public let triggerType: TriggerType
    public let abilityTags: Set<RPAbilityTag>
    public let targeting: RPTargeting<RP>?
    public let ability: RPAbility<RP>
    public let chancePercent: RPValue
    public let cooldown: RPTimeIncrement

    /// `code` keys this trigger's cooldown on whichever owner holds it. A nil
    /// `targeting` uses the ability's own rules; supplying one overrides them,
    /// which is what lets an ability serve both a cast and a reaction — and is
    /// also the gate, since an empty target set yields no event.
    public init(
        code: RPReferenceCode? = nil,
        triggerType: TriggerType,
        abilityTags: Set<RPAbilityTag> = [],
        targeting: RPTargeting<RP>? = nil,
        ability: RPAbility<RP>,
        chancePercent: RPValue = RPChance.certain,
        cooldown: RPTimeIncrement = 0
    ) {
        self.code = code ?? ability.code
        self.triggerType = triggerType
        self.abilityTags = abilityTags
        self.targeting = targeting
        self.ability = ability
        self.chancePercent = chancePercent
        self.cooldown = cooldown
    }

    /// Whether a resolved event is the kind of thing this trigger answers, on
    /// role and tags alone — cooldown, chance and targeting are gated elsewhere.
    /// `postEvent` matches every event in the space; an empty `abilityTags` is a
    /// subset of everything, so declaring none wakes on anything.
    public func matches(_ result: RPEventResult<RP>, owner ownerId: RPBodyId) -> Bool {
        switch triggerType {
        case .postEvent:
            break
        case .postEventInitiated:
            guard result.event.initiator == ownerId else { return false }
        case .postEventTargeted:
            guard result.event.targets.contains(ownerId) else { return false }
        }
        return abilityTags.isSubset(of: result.event.ability.tags)
    }

    /// Builds the reaction the owner would perform, or nil when it would hit
    /// nobody — the ordinary outcome, not an error, and callers spend no
    /// cooldown, charge or roll on it. The whole triggering event is threaded
    /// through so the reaction's sub-abilities can aim at the attacker too.
    public func makeEvent(
        owner ownerId: RPBodyId,
        reactingTo triggeringEvent: RPEvent<RP>,
        in rpSpace: RP
    ) -> RPEvent<RP>? {
        let event = RPEvent(
            category: .triggered,
            initiator: ownerId,
            ability: ability,
            targets: targeting?.getValidTargets(
                for: ownerId,
                in: rpSpace,
                reactingTo: triggeringEvent
            ),
            reactingTo: triggeringEvent,
            rpSpace: rpSpace
        )
        return event.targets.isEmpty ? nil : event
    }
}
