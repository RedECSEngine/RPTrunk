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
