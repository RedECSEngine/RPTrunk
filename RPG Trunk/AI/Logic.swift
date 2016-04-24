
public struct Priority {
    
    public let ability:Ability  // Executable Ability
    public let conditionals:[Conditional]? //Conditions, if none then this priority will always validate
    
    public init (ability:Ability, conditionals:[Conditional]?) {
        
        self.ability = ability
        self.conditionals = conditionals
    }
    
    public func evaluate(entity:RPEntity) -> Bool {
        
        guard let conditionals = self.conditionals else {
            return true //this priority always passes if it has no conditions
        }
        
        return checkConditionals(conditionals, entity: entity)
    }
    
}