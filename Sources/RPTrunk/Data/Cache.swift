import Foundation

open class RPCache {
    public enum CacheError: Error {
        case notFound(String)
        case invalidFormat(String)
    }

    public var abilities: [String: Ability] = [:]
    public var statusEffects: [String: StatusEffect] = [:]
    public var entities: [String: Entity] = [:]
    
    public init() {}
    
    public func load(_ data: RPCacheJSON) throws {
        try loadStatusEffects(data.statusEffects ?? [:])
        try loadAbilities(data.abilities ?? [:])
        try loadEntities(data.entities ?? [:])
    }

    public func loadAbilities(_ abilities: [String: AbilityJSON]) throws {
        try abilities.forEach { (name, data) in
            let components: [Component] = try buildComponent(data)
            var ability = Ability(name: name, components: components, cooldown: data.cooldown)
            ability.metadata = data.metadata
            self.abilities[name] = ability
        }
    }

    public func loadStatusEffects(_ statusEffects: [String: StatusEffectJSON]) throws {
        try statusEffects.forEach { (name, data) in
            let components: [Component] = try buildComponent(data)
            let se = StatusEffect(
                name: name, labels: [],
                components: components,
                duration: data.duration,
                charges: data.charges,
                impairsAction: data.impairsAction ?? false
            )
            self.statusEffects[name] = se
        }
    }

    public func loadEntities(_ entities: [String: EntityJSON]) throws {
        entities.forEach {(name, data) in
            let stats: [String: RPValue] = data.stats ?? [:]
            var entity = Entity.new(cache: self)
            entity.baseStats = Stats(stats)
            entity.currentStats = Stats(stats)
            data.abilities?.forEach {
                ability in
                let conditional = Conditional(ability.conditional)
                if let ability = self.abilities[ability.name] {
                    entity.addExecutableAbility(ability, conditional: conditional)
                }
            }
            self.entities[name] = entity
        }
    }

    public func buildComponent(_ component: ComponentsContainerJSON) throws -> [Component] {
        var components: [Component] = []
        
        if let stats = component.stats {
            components.append(Component(stats: Stats(stats)))
        }
        if let cost = component.cost {
            components.append(Component(cost: Stats(cost)))
        }
        if let requirements = component.requirements {
            components.append(Component(requirements: Stats(requirements)))
        }
        if let statusEffects = component.statusEffects {
            components += try statusEffects.map { try getStatusEffect($0) }
        }
        if let target = component.target {
            let type = Targeting.fromString(target)
            components.append(Component(targetType: type))
        }
        if let discharge = component.discharge {
            components.append(Component(dischargedStatusEffects: discharge))
        }
        if let c = component.components {
            components += try c.map { try getComponent($0) }
        }
        
        return components
    }

    public func buildConditional(_ data: [String: AnyObject]) -> Conditional {
        if let query = data["conditional"] as? String {
            return Conditional(query)
        }
        return .always
    }

    public func getAbility(_ name: String) throws -> Ability {
        if let ability = abilities[name] {
            return ability
        }
        throw RPCache.CacheError.notFound(name)
    }

    public func getStatusEffect(_ name: String) throws -> Component {
        if let se = statusEffects[name] {
            return Component(statusEffects: [se])
        }
        throw RPCache.CacheError.notFound(name)
    }

    public func getComponent(_ name: String) throws -> Component {
        // TODO: expand this function to try other types of components before throwing an error
        guard let se = try? getStatusEffect(name) else {
            throw RPCache.CacheError.notFound(name)
        }
        return se
    }

    public func newEntity(_ name: String) throws -> Entity {
        guard let entity = entities[name] else {
            throw RPCache.CacheError.notFound(name)
        }
        return entity.copy()
    }
}
