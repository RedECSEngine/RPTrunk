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
            let components: [Component] = try buildComponent(data)
            var ability = RPAbility<RP>(code: code, displayName: data.displayName, components: components, cooldown: data.cooldown)
            ability.metadata = data.metadata
            self.abilities[code] = ability
        }
    }

    public func loadStatusEffects(_ statusEffects: [RPReferenceCode: StatusEffectJSON<RP>]) throws {
        try statusEffects.forEach { (code, data) in
            let components: [Component<RP>] = try buildComponent(data)
            let se = RPStatusEffect<RP>(
                code: code,
                displayName: data.displayName,
                tags: [],
                components: components,
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
            entity.baseStats = stats
            entity.displayName = data.displayName ?? code
            entity.currentStats = stats
            data.abilities?.forEach {
                ability in
                let conditional = Conditional<RP>(ability.conditional)
                if let ability = self.abilities[ability.code] {
                    entity.addExecutableAbility(ability, conditional: conditional)
                }
            }
            self.entities[code] = entity
        }
    }

    public func loadItems(_ items: [RPReferenceCode: ItemJSON<RP>]) throws {
        try items.forEach { (code, data) in
            let components: [Component<RP>] = try buildComponent(data)
            let ability = try data.ability.map { try getAbility($0) }
            let conditional = Conditional<RP>(data.conditional ?? "always")
            var item = RPItem<RP>(
                code: code,
                displayName: data.displayName,
                maximumStack: data.maximumStack,
                components: components,
                ability: ability,
                conditional: conditional
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

    public func buildComponent<C: ComponentsContainerJSON>(_ component: C) throws -> [Component<RP>] where C.Stats == RP.Stats  {
        var components: [Component<RP>] = []
        
        if let stats = component.stats {
            components.append(Component(stats: stats))
        }
        if let cost = component.cost {
            components.append(Component(cost: cost))
        }
        if let requirements = component.requirements {
            components.append(Component(requirements: requirements))
        }
        if let statusEffects = component.statusEffects {
            components += try statusEffects.map { try getStatusEffect($0) }
        }
        if let target = component.target {
            let type = RPTargeting<RP>.fromString(target)
            components.append(Component<RP>(targetType: type))
        }
        if let discharge = component.discharge {
            components.append(Component<RP>(dischargedStatusEffects: discharge))
        }
        if let c = component.components {
            components += try c.map { try getComponent($0) }
        }
        
        return components
    }

    public func buildConditional(_ data: [String: AnyObject]) -> Conditional<RP> {
        if let query = data["conditional"] as? String {
            return Conditional(query)
        }
        return .always
    }

    public func getAbility(_ name: String) throws -> RPAbility<RP> {
        if let ability = abilities[name] {
            return ability
        }
        throw RPCache.CacheError.notFound(name)
    }

    public func getStatusEffect(_ name: String) throws -> Component<RP> {
        if let se = statusEffects[name] {
            return Component<RP>(statusEffects: [se])
        }
        throw RPCache.CacheError.notFound(name)
    }

    public func getComponent(_ name: String) throws -> Component<RP> {
        // TODO: expand this function to try other types of components before throwing an error
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
