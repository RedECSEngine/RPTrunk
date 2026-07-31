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
        try loadBodies(data.bodies ?? [:])
        try loadItems(data.items ?? [:])
    }

    public func loadAbilities(_ abilities: [RPReferenceCode: RPAbilityJSON<RP>]) throws {
        try abilities.forEach { (code, data) in
            let fragments: [RPFragment] = try buildFragments(data)
            var ability = RPAbility<RP>(code: code, displayName: data.displayName, fragments: fragments, cooldown: data.cooldown)
            ability.metadata = data.metadata
            self.abilities[code] = ability
        }
    }

    public func loadStatusEffects(_ statusEffects: [RPReferenceCode: RPStatusEffectJSON<RP>]) throws {
        try statusEffects.forEach { (code, data) in
            let fragments: [RPFragment<RP>] = try buildFragments(data)
            let se = RPStatusEffect<RP>(
                code: code,
                displayName: data.displayName,
                tags: [],
                fragments: fragments,
                duration: data.duration,
                charges: data.charges,
                impairsAction: data.impairsAction ?? false,
                period: data.period ?? RPStatusEffect<RP>.defaultPeriod
            )
            self.statusEffects[code] = se
        }
    }

    public func loadBodies(_ bodies: [RPReferenceCode: RPBodyJSON<RP>]) throws {
        bodies.forEach {(code, data) in
            let stats = data.stats ?? .zero
            var body = RPBody<RP>.new(cache: self)
            body.code = code
            body.setBaseStats(stats)
            body.displayName = data.displayName ?? code
            body.equipment.equipmentSlotCapacities = data.equipmentSlots ?? [:]
            data.abilities?.forEach {
                ability in
                let conditional = RPConditional<RP>(ability.conditional)
                if let ability = self.abilities[ability.code] {
                    body.addExecutableAbility(ability, conditional: conditional)
                }
            }
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
        if let cost = fragment.cost {
            fragments.append(RPFragment(cost: cost))
        }
        if let requirements = fragment.requirements {
            fragments.append(RPFragment(requirements: requirements))
        }
        if let statusEffects = fragment.statusEffects {
            fragments += try statusEffects.map { try getStatusEffect($0) }
        }
        if let target = fragment.target {
            let type = RPTargeting<RP>.fromString(target)
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
