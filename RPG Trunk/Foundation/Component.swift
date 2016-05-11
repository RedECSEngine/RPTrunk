
public protocol Component {
    
    func getStats() -> RPStats?
    func getCost() -> RPStats?
    func getRequirements() -> RPStats?
    func getTargetType() -> EventTargetType?
}

func combineComponentStats(components:[Component]) -> RPStats {
    
    return components
        .flatMap { $0.getStats() }
        .reduce(RPStats(), combine: +)
}

func combineComponentCosts(components:[Component]) -> RPStats {
    
    return components
        .flatMap { $0.getCost() }
        .reduce(RPStats(), combine: +)
}

func combineComponentRequirements(components:[Component]) -> RPStats {
    
    return components
        .flatMap { $0.getRequirements() }
        .reduce(RPStats(), combine: +)
}

func combineComponentTargetTypes(components:[Component]) -> EventTargetType {

    for component in components {
        if let t = component.getTargetType() {
            return t
        }
    }
    return .SingleEnemy
}

public struct BasicComponent: Component {

    public let stats:RPStats?
    public let cost:RPStats?
    public let requirements:RPStats?
    public let targetType:EventTargetType?
    
    public init(stats:RPStats?, cost:RPStats?, requirements:RPStats?, targetType:EventTargetType?) {
        
        self.stats = stats
        self.cost = cost
        self.requirements = requirements
        self.targetType = targetType
    }
    
    public init(stats:RPStats?) {
        self.stats = stats
        self.cost = nil
        self.requirements = nil
        self.targetType = nil
    }
    
    public init(cost:RPStats?) {
        self.stats = nil
        self.cost = cost
        self.requirements = nil
        self.targetType = nil
    }
    
    public init(requirements:RPStats?) {
        self.stats = nil
        self.cost = nil
        self.requirements = requirements
        self.targetType = nil
    }
    
    public init(targetType:EventTargetType?) {
        self.stats = nil
        self.cost = nil
        self.requirements = nil
        self.targetType = targetType
    }
    
    public init(fromComponents:[Component]) {
        
        self.stats = combineComponentStats(fromComponents)
        self.cost = combineComponentCosts(fromComponents)
        self.requirements = combineComponentRequirements(fromComponents)
        self.targetType = combineComponentTargetTypes(fromComponents)
    }
    
    public func getStats() -> RPStats? { return stats }
    public func getCost() -> RPStats? { return cost }
    public func getRequirements() -> RPStats? { return requirements }
    public func getTargetType() -> EventTargetType? { return targetType }
}
