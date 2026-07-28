import Foundation // TODO: Use foundation essentials

open class RPCache<RP: RPSpace> {
    public enum CacheError: Error {
        case notFound(String)
        case invalidFormat(String)
    }
    
    typealias AbilityData = AbilityJSON<RP>

    public var abilities: [RPReferenceCode: RPAbility<RP>] = [:]
    public var statusEffects: [RPReferenceCode: RPStatusEffect<RP>] = [:]
    public var entities: [RPReferenceCode: RPEntity<RP>] = [:]
    public var items: [RPReferenceCode: RPItem<RP>] = [:]

    public init() {}

    public func load(_ data: RPCacheJSON<RP>) throws {
        try loadStatusEffects(data.statusEffects ?? [:])
        try loadAbilities(data.abilities ?? [:])
        try loadEntities(data.entities ?? [:])
        try loadItems(data.items ?? [:])
    }

    public func loadAbilities(_ abilities: [RPReferenceCode: AbilityJSON<RP>]) throws {
        try abilities.forEach { (code, data) in
            let fragments: [RPFragment] = try buildFragments(data)
            var ability = RPAbility<RP>(code: code, displayName: data.displayName, fragments: fragments, cooldown: data.cooldown)
            ability.metadata = data.metadata
            self.abilities[code] = ability
        }
    }

    public func loadStatusEffects(_ statusEffects: [RPReferenceCode: StatusEffectJSON<RP>]) throws {
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

    public func loadEntities(_ entities: [RPReferenceCode: EntityJSON<RP>]) throws {
        entities.forEach {(code, data) in
            let stats = data.stats ?? .zero
            var entity = RPEntity<RP>.new(cache: self)
            entity.code = code
            entity.setBaseStats(stats)
            entity.displayName = data.displayName ?? code
            entity.body.equipmentSlotCapacities = data.equipmentSlots ?? [:]
            data.abilities?.forEach {
                ability in
                let conditional = RPConditional<RP>(ability.conditional)
                if let ability = self.abilities[ability.code] {
                    entity.addExecutableAbility(ability, conditional: conditional)
                }
            }
            self.entities[code] = entity
        }
    }

    public func loadItems(_ items: [RPReferenceCode: ItemJSON<RP>]) throws {
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

    public func buildFragments<C: FragmentsContainerJSON>(_ fragment: C) throws -> [RPFragment<RP>] where C.Stats == RP.Stats  {
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

    public func newEntity(_ name: String) throws -> RPEntity<RP> {
        guard var entity = entities[name] else {
            throw RPCache.CacheError.notFound(name)
        }
        entity.id = UUID().uuidString
        return entity
    }
}
