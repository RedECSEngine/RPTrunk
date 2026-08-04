import Foundation // TODO: Use foundation essentials

open class RPCache<RP: RPSpace> {
    public enum CacheError: Error {
        case notFound(String)
        case invalidFormat(String)
    }
    
    typealias AbilityData = RPAbilityJSON<RP>

    public var abilities: [RPReferenceCode: RPAbility<RP>] = [:]
    public var statusEffects: [RPReferenceCode: RPStatusEffect<RP>] = [:]
    public var bodies: [RPReferenceCode: RPBody<RP>] = [:]
    public var items: [RPReferenceCode: RPItem<RP>] = [:]

    public init() {}

    public func load(_ data: RPCacheJSON<RP>) throws {
        try loadStatusEffects(data.statusEffects ?? [:])
        try loadAbilities(data.abilities ?? [:])
        try loadStatusEffectTriggers(data.statusEffects ?? [:]) // needs the abilities above
        try loadBodies(data.bodies ?? [:])
        try loadItems(data.items ?? [:])
    }

    public func loadAbilities(_ abilities: [RPReferenceCode: RPAbilityJSON<RP>]) throws {
        try abilities.forEach { (code, data) in
            let fragments: [RPFragment] = try buildFragments(data)
            var ability = RPAbility<RP>(
                code: code,
                displayName: data.displayName,
                tags: Set(data.tags ?? []),
                fragments: fragments,
                cooldown: data.cooldown
            )
            ability.metadata = data.metadata
            self.abilities[code] = ability
        }

        try abilities.forEach { (code, data) in
            guard let subAbilities = data.subAbilities else { return }
            let resolved = try subAbilities.map { try getAbility($0) }
            self.abilities[code]?.subAbilities = resolved
        }
    }

    public func loadStatusEffects(_ statusEffects: [RPReferenceCode: RPStatusEffectJSON<RP>]) throws {
        try statusEffects.forEach { (code, data) in
            let persistent: [RPFragment<RP>] = try (data.persistentFragments ?? [])
                .flatMap { try buildFragments($0) }
            let periodic: [RPFragment<RP>] = try (data.periodicFragments ?? [])
                .flatMap { try buildFragments($0) }
            let se = RPStatusEffect<RP>(
                code: code,
                displayName: data.displayName,
                tags: Set(data.tags ?? []),
                persistentFragments: persistent,
                periodicFragments: periodic,
                duration: data.duration,
                charges: data.charges,
                period: data.period ?? RPStatusEffect<RP>.defaultPeriod
            )
            self.statusEffects[code] = se
        }
    }

    /// The second pass over status effects, run once abilities exist so a
    /// trigger can name one. Same exclusivity care as `loadAbilities`: resolve
    /// into a local, then assign.
    public func loadStatusEffectTriggers(
        _ statusEffects: [RPReferenceCode: RPStatusEffectJSON<RP>]
    ) throws {
        try statusEffects.forEach { (code, data) in
            guard let triggers = data.triggers else { return }
            let resolved = try triggers.map { try buildTrigger($0) }
            self.statusEffects[code]?.triggers = resolved
        }
    }

    /// Resolves one authored trigger, throwing rather than degrading.
    ///
    /// A trigger that quietly never fires is the worst failure this system has —
    /// it looks like a balance problem and reads like working data — so an
    /// unrecognized `triggerType` is an error, and so is aiming at `initiator`
    /// on `postEventInitiated`, where the initiator is by definition the
    /// trigger's own owner and the reaction could only ever target nobody. That
    /// check reads the *effective* targeting: the override if one is given, the
    /// ability's own rules otherwise.
    public func buildTrigger(_ data: RPTriggerJSON<RP>) throws -> RPTrigger<RP> {
        guard let triggerType = RPTrigger<RP>.TriggerType(rawValue: data.triggerType) else {
            throw CacheError.invalidFormat("unrecognized triggerType `\(data.triggerType)`")
        }

        let ability = try getAbility(data.ability)
        let targeting = try data.target.map { try RPTargeting<RP>.fromString($0) }

        guard !(triggerType == .postEventInitiated
                && (targeting ?? ability.targeting).type == .initiator)
        else {
            throw CacheError.invalidFormat(
                "trigger `\(data.ability)` targets `initiator` on `postEventInitiated`, where the initiator is the trigger's own owner — use `target: oneself`"
            )
        }

        return RPTrigger<RP>(
            code: data.code,
            triggerType: triggerType,
            abilityTags: Set(data.abilityTags ?? []),
            targeting: targeting,
            ability: ability,
            chancePercent: data.chancePercent ?? RPChance.certain,
            cooldown: data.cooldown ?? 0
        )
    }

    public func loadBodies(_ bodies: [RPReferenceCode: RPBodyJSON<RP>]) throws {
        try bodies.forEach {(code, data) in
            let stats = data.stats ?? .zero
            var body = RPBody<RP>.new(cache: self)
            body.code = code
            body.setBaseStats(stats)
            body.displayName = data.displayName ?? code
            body.metadata = data.metadata
            body.equipment.equipmentSlotCapacities = data.equipmentSlots ?? [:]
            data.abilities?.forEach {
                ability in
                let conditional = RPConditional<RP>(ability.conditional)
                if let ability = self.abilities[ability.code] {
                    body.addExecutableAbility(ability, conditional: conditional)
                }
            }
            // unlike an ability reference, a trigger naming a missing ability throws
            try data.triggers?.forEach { body.addTrigger(try buildTrigger($0)) }
            self.bodies[code] = body
        }
    }

    public func loadItems(_ items: [RPReferenceCode: RPItemJSON<RP>]) throws {
        try items.forEach { (code, data) in
            let fragments: [RPFragment<RP>] = try buildFragments(data)
            let ability = try data.ability.map { try getAbility($0) }
            let conditional = RPConditional<RP>(data.conditional ?? "always")
            var item = RPItem<RP>(
                code: code,
                displayName: data.displayName,
                maximumStack: data.maximumStack,
                fragments: fragments,
                ability: ability,
                conditional: conditional,
                equipmentSlotCode: data.equipmentSlotCode
            )
            item.metadata = data.metadata
            self.items[code] = item
        }
    }

    public func getItem(_ code: RPReferenceCode) throws -> RPItem<RP> {
        guard let item = items[code] else {
            throw RPCache.CacheError.notFound(code)
        }
        return item
    }

    public func newActiveItem(_ code: RPReferenceCode, amount: Int = 1) throws -> RPActiveItem<RP> {
        RPActiveItem(item: try getItem(code), amount: amount)
    }

    public func buildFragments<C: RPFragmentsContainerJSON>(_ fragment: C) throws -> [RPFragment<RP>] where C.Stats == RP.Stats  {
        var fragments: [RPFragment<RP>] = []
        
        if let stats = fragment.stats {
            fragments.append(RPFragment(stats: stats))
        }
        if let statsCost = fragment.statsCost {
            fragments.append(RPFragment(statsCost: statsCost))
        }
        if let requiredStats = fragment.requiredStats {
            fragments.append(RPFragment(requiredStats: requiredStats))
        }
        if let requiredStatuses = fragment.requiredStatuses {
            fragments.append(RPFragment(requiredStatuses: requiredStatuses.map { RPStatusRequirement($0) }))
        }
        if let threatRequirement = fragment.threatRequirement {
            fragments.append(RPFragment(threatRequirement: threatRequirement))
        }
        if let threatCost = fragment.threatCost {
            fragments.append(RPFragment(threatCost: threatCost))
        }
        if let statusEffects = fragment.statusEffects {
            fragments += try statusEffects.map { try getStatusEffect($0) }
        }
        if let target = fragment.target {
            let type = try RPTargeting<RP>.fromString(target)
            fragments.append(RPFragment<RP>(targetType: type))
        }
        if let discharge = fragment.discharge {
            fragments.append(RPFragment<RP>(dischargedStatusEffects: discharge))
        }
        if let c = fragment.fragments {
            fragments += try c.map { try getFragment($0) }
        }
        
        return fragments
    }

    public func buildConditional(_ data: [String: AnyObject]) -> RPConditional<RP> {
        if let query = data["conditional"] as? String {
            return RPConditional(query)
        }
        return .always
    }

    public func getAbility(_ name: String) throws -> RPAbility<RP> {
        if let ability = abilities[name] {
            return ability
        }
        throw RPCache.CacheError.notFound(name)
    }

    public func getStatusEffect(_ name: String) throws -> RPFragment<RP> {
        if let se = statusEffects[name] {
            return RPFragment<RP>(statusEffects: [se])
        }
        throw RPCache.CacheError.notFound(name)
    }

    public func getFragment(_ name: String) throws -> RPFragment<RP> {
        // TODO: expand this function to try other types of fragments before throwing an error
        guard let se = try? getStatusEffect(name) else {
            throw RPCache.CacheError.notFound(name)
        }
        return se
    }

    public func newBody(_ name: String) throws -> RPBody<RP> {
        guard var body = bodies[name] else {
            throw RPCache.CacheError.notFound(name)
        }
        body.id = UUID().uuidString
        return body
    }
}
