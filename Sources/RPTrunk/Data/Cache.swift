import Foundation

open class RPCache<RP: RPSpace> {
    public enum CacheError: Error {
        case notFound(String)
        case invalidFormat(String)
    }

    public var abilities: [String: Ability<RP>] = [:]
    public var statusEffects: [String: StatusEffect<RP>] = [:]
    public var entities: [String: RPEntity<RP>] = [:]
    
    public init() {}
    
    public func load(_ data: RPCacheJSON<RP.Stats>) throws {
        try loadStatusEffects(data.statusEffects ?? [:])
        try loadAbilities(data.abilities ?? [:])
        try loadEntities(data.entities ?? [:])
    }

    public func loadAbilities(_ abilities: [String: AbilityJSON<RP.Stats>]) throws {
        try abilities.forEach { (name, data) in
            let components: [Component] = try buildComponent(data)
            var ability = Ability<RP>(name: name, components: components, cooldown: data.cooldown)
            ability.metadata = data.metadata
            self.abilities[name] = ability
        }
    }

    public func loadStatusEffects(_ statusEffects: [String: StatusEffectJSON<RP.Stats>]) throws {
        try statusEffects.forEach { (name, data) in
            let components: [Component<RP>] = try buildComponent(data)
            let se = StatusEffect<RP>(
                name: name,
                tags: [],
                components: components,
                duration: data.duration,
                charges: data.charges,
                impairsAction: data.impairsAction ?? false
            )
            self.statusEffects[name] = se
        }
    }

    public func loadEntities(_ entities: [String: EntityJSON<RP.Stats>]) throws {
        entities.forEach {(name, data) in
            let stats = data.stats ?? .zero
            var entity = RPEntity<RP>.new(cache: self)
            entity.baseStats = stats
            entity.currentStats = stats
            data.abilities?.forEach {
                ability in
                let conditional = Conditional<RP>(ability.conditional)
                if let ability = self.abilities[ability.name] {
                    entity.addExecutableAbility(ability, conditional: conditional)
                }
            }
            self.entities[name] = entity
        }
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
            let type = Targeting<RP>.fromString(target)
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

    public func getAbility(_ name: String) throws -> Ability<RP> {
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
        guard let entity = entities[name] else {
            throw RPCache.CacheError.notFound(name)
        }
        return entity.copy()
    }
}
