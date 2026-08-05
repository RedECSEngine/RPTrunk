public enum RPChance {
    public static let certain: RPValue = 10000
}

public enum RPTriggerSource: Codable, Equatable, Hashable {
    case body
    case statusEffect(RPReferenceCode)
}

public struct RPTriggerCandidate<RP: RPSpace> {
    public let owner: RPBodyId
    public let source: RPTriggerSource
    public let trigger: RPTrigger<RP>
    public let event: RPEvent<RP>

    public init(
        owner: RPBodyId,
        source: RPTriggerSource,
        trigger: RPTrigger<RP>,
        event: RPEvent<RP>
    ) {
        self.owner = owner
        self.source = source
        self.trigger = trigger
        self.event = event
    }
}

func tickTriggerCooldowns(
    _ cooldowns: inout [RPReferenceCode: RPTimeIncrement],
    by delta: RPTimeIncrement
) {
    for code in cooldowns.keys {
        let remaining = (cooldowns[code] ?? 0) - delta
        cooldowns[code] = remaining > 0 ? remaining : nil
    }
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
