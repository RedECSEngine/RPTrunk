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

    public var defaultBody: RPBody<RP>?

    public init() {}

    public func load(_ data: RPCacheJSON<RP>) throws {
        try loadStatusEffects(data.statusEffects ?? [:])
        try loadAbilities(data.abilities ?? [:])
        try loadStatusEffectTriggers(data.statusEffects ?? [:])
        try loadDefaultBody(data.defaultBody)
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
            ability.executionRange = data.executionRange
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

    public func loadStatusEffectTriggers(
        _ statusEffects: [RPReferenceCode: RPStatusEffectJSON<RP>]
    ) throws {
        try statusEffects.forEach { (code, data) in
            guard let triggers = data.triggers else { return }
            let resolved = try triggers.map { try buildTrigger($0) }
            self.statusEffects[code]?.triggers = resolved
        }
    }

    public func buildTrigger(_ data: RPTriggerJSON<RP>) throws -> RPTrigger<RP> {
        guard let triggerType = RPTrigger<RP>.TriggerType(rawValue: data.triggerType) else {
            throw CacheError.invalidFormat("unrecognized triggerType `\(data.triggerType)`")
        }

        let ability = try getAbility(data.ability)
        let targeting = try data.target.map { try RPTargeting<RP>.fromString($0) }

        guard !(triggerType == .postEventInitiated
                && (targeting ?? ability.targeting).pool == .initiator)
        else {
            throw CacheError.invalidFormat(
                "trigger `\(data.ability)` targets `initiator` on `postEventInitiated`, where the initiator is the trigger's own owner — use `self`"
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

    public func loadDefaultBody(_ data: RPBodyJSON<RP>?) throws {
        guard let data else { return }
        defaultBody = try buildBody(code: nil, from: data, startingFrom: RPBody<RP>())
    }

    public func loadBodies(_ bodies: [RPReferenceCode: RPBodyJSON<RP>]) throws {
        try bodies.forEach { (code, data) in
            self.bodies[code] = try buildBody(
                code: code,
                from: data,
                startingFrom: RPBody<RP>.new(cache: self)
            )
        }
    }

    func buildBody(
        code: RPReferenceCode?,
        from data: RPBodyJSON<RP>,
        startingFrom base: RPBody<RP>
    ) throws -> RPBody<RP> {
        var body = base
        body.code = code
        body.setBaseStats(data.stats ?? .zero)
        if let displayName = data.displayName ?? code {
            body.displayName = displayName
        }
        body.metadata = data.metadata
        if let targetingRange = data.targetingRange {
            body.targetingRange = targetingRange
        }
        body.equipment.equipmentSlotCapacities = data.equipmentSlots ?? [:]
        data.abilities?.forEach { reference in
            let conditional = RPConditional<RP>(reference.conditional)
            if let ability = self.abilities[reference.code] {
                body.addExecutableAbility(ability, conditional: conditional)
            }
        }
        try data.triggers?.forEach { body.addTrigger(try buildTrigger($0)) }
        return body
    }

    public func loadItems(_ items: [RPReferenceCode: RPItemJSON<RP>]) throws {
        try items.forEach { (code, data) in
            let fragments: [RPFragment<RP>] = try buildFragments(data)
            let ability = try data.ability.map { try getAbility($0) }
            let conditional = RPConditional<RP>(data.conditional ?? "always")
            var item = RPItem<RP>(
                code: code,
                displayName: data.displayName,
                tags: Set(data.tags ?? []),
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
