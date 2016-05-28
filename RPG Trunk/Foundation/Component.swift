
public protocol Component {
    
    func getStats() -> Stats?
    func getCost() -> Stats?
    func getRequirements() -> Stats?
    func getTargetType() -> TargetType?
    func getStatusEffects() -> [StatusEffect]
    func getDischargedStatusEffects() -> [String]
}

extension Component {
    public func getStats() -> Stats? {
        return nil
    }
    
    public func getTargetType() -> TargetType? {
        return nil
    }
    
    public func getCost() -> Stats? {
        return nil
    }
    
    public func getRequirements() -> Stats? {
        return nil
    }
    
    public func getStatusEffects() -> [StatusEffect] {
        return []
    }
    
    public func getDischargedStatusEffects() -> [String] {
        return []
    }
}

public protocol ComponentContainer {
    var components:[Component] { get }
}

extension ComponentContainer {

    public var stats:Stats {
        
        return components
            .flatMap { $0.getStats() }
            .reduce(Stats(), combine: +)
    }

    public var cost:Stats {
        
        return components
            .flatMap { $0.getCost() }
            .reduce(Stats(), combine: +)
    }

    public var requirements:Stats {
        
        return components
            .flatMap { $0.getRequirements() }
            .reduce(Stats(), combine: +)
    }

    public var targetType:TargetType {

        for component in components {
            if let t = component.getTargetType() {
                return t
            }
        }
        return .SingleEnemy(.Always)
    }

    public var statusEffects: [StatusEffect] {
        return components
            .flatMap { $0.getStatusEffects() }
    }

    public var dischargedStatusEffects:[String] {
        return components
            .flatMap { $0.getDischargedStatusEffects() }
    }
}

func ==(a:ComponentContainer, b:ComponentContainer) -> Bool {
    return a.stats == b.stats
        && a.cost == b.cost
        && a.requirements == b.requirements
        && a.targetType == b.targetType
        && a.statusEffects == b.statusEffects
        && a.dischargedStatusEffects == b.dischargedStatusEffects
 }

public struct BasicComponent: Component {
    
    private struct IntermediaryContainer: ComponentContainer {
        let components: [Component]
    }

    public let stats: Stats?
    public let cost: Stats?
    public let requirements: Stats?
    public let targetType:TargetType?
    public let statusEffects: [StatusEffect]?
    public let dischargedStatusEffects: [String]?
    
    public init(stats: Stats) {
        self.stats = stats
        self.cost = nil
        self.requirements = nil
        self.targetType = nil
        self.statusEffects = nil
        self.dischargedStatusEffects = nil
    }
    
    public init(cost: Stats) {
        self.stats = nil
        self.cost = cost
        self.requirements = nil
        self.targetType = nil
        self.statusEffects = nil
        self.dischargedStatusEffects = nil
    }
    
    public init(requirements: Stats) {
        self.stats = nil
        self.cost = nil
        self.requirements = requirements
        self.targetType = nil
        self.statusEffects = nil
        self.dischargedStatusEffects = nil
    }
    
    public init(targetType:TargetType) {
        self.stats = nil
        self.cost = nil
        self.requirements = nil
        self.targetType = targetType
        self.statusEffects = nil
        self.dischargedStatusEffects = nil
    }
    
    public init(statusEffects:[StatusEffect]) {
        self.stats = nil
        self.cost = nil
        self.requirements = nil
        self.targetType = nil
        self.statusEffects = statusEffects
        self.dischargedStatusEffects = nil
    }
    
    public init(dischargedStatusEffects:[String]) {
        self.stats = nil
        self.cost = nil
        self.requirements = nil
        self.targetType = nil
        self.statusEffects = nil
        self.dischargedStatusEffects = dischargedStatusEffects
    }
    
    public init(fromComponents:[Component]) {
        
        let container = IntermediaryContainer(components:fromComponents)
        
        self.stats = container.stats
        self.cost = container.cost
        self.requirements = container.requirements
        self.targetType = container.targetType
        self.statusEffects = container.statusEffects
        self.dischargedStatusEffects = container.dischargedStatusEffects
    }
    
    public func getStats() -> Stats? { return stats }
    public func getCost() -> Stats? { return cost }
    public func getRequirements() -> Stats? { return requirements }
    public func getTargetType() -> TargetType? { return targetType }
    public func getStatusEffects() -> [StatusEffect] { return statusEffects ?? [] }
    public func getDischargedStatusEffects() -> [String] { return dischargedStatusEffects ?? [] }
    
}
