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

    /// `code` keys this trigger's cooldown on whichever owner holds it, and
    /// defaults to the ability's own code — pass one explicitly only when a
    /// single owner carries two triggers around the same ability and they
    /// should cool down separately.
    ///
    /// A nil `targeting` means "use the ability's own rules"; supplying one
    /// overrides them, which is what lets a single ability serve both a direct
    /// cast and a reaction. It also doubles as the trigger's gate, since
    /// `RPTargeting` carries a conditional and an empty target set yields no
    /// event.
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

    /// Whether a resolved event is the *kind* of thing this trigger answers,
    /// judged purely on the owner's role in it and the ability's tags. It says
    /// nothing about whether the reaction can actually produce targets — that
    /// is `makeEvent`'s job — nor about cooldown or chance, which the caller
    /// gates separately.
    ///
    /// `postEvent` matches every event in the space, including ones the owner
    /// took no part in. An empty `abilityTags` is a subset of every ability's
    /// tags, so a trigger declaring none wakes on anything its type admits.
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
    /// nobody. Returning nil is the ordinary outcome, not an error: a
    /// `.initiator` aim finds nothing when the triggering event had no
    /// initiator or when that initiator *is* the owner, and any targeting whose
    /// conditional excludes everyone resolves empty. Callers treat nil as "this
    /// trigger did not fire", so no cooldown, charge or chance roll is spent.
    ///
    /// The triggering event is threaded through rather than just its initiator
    /// so that the reaction's own sub-abilities resolve their targeting against
    /// it too — an explicit target set would not reach them.
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
