public class Team: InventoryManager {
    
    public var id: String = UUID().uuidString
    public private(set) var entities: [Entity] = []
    public var inventory: [Storable] = []
    
    public init() {
    
    }
    
    public func add(_ entity: Entity) {
    
        entity.teamId = self.id
        entities.append(entity)
    }
}

open class RPSpace: Temporal, InventoryManager {

    public var inventory: [Storable] = []
    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement = -1
    
    open var teams: [String: Team] = [:]
    
    public init() {
        
    }
    
    open func tick(_ moment: Moment) {
        let newMoment = moment.addSibling(self)
        teams.values
            .flatMap { $0.entities }
            .forEach { $0.tick(newMoment) }
    }
    
    public func getPendingEvents() -> [Event] {
        return getPendingEvents(in: self)
    }
    
    public func getPendingEvents(in rpSpace: RPSpace) -> [Event] {
        return getAllPendingPassiveEvents() + getAllPendingExecutableEvents()
    }

    private func getAllPendingPassiveEvents() -> [Event] {
        return teams.values
            .flatMap { $0.entities }
            .flatMap { $0.getPendingPassiveEvents(in: self) }
    }
    
    private func getAllPendingExecutableEvents() -> [Event] {
        return teams.values
            .flatMap { $0.entities }
            .flatMap { $0.getPendingExecutableEvents(in: self) }
    }
    
    open func performEvents(_ events:[Event]) -> [EventResult] {
        
        let mainEventResults = events
            .flatMap { event -> [Event] in
                event.resetCooldowns()
                return [event]
            }
            .map { $0.execute(in: self) }
        
        let reactionEventResults = mainEventResults.flatMap {
            (eventResult) -> [Event] in
            eventResult.effects.flatMap({
                conflictResult -> [Event] in
                return conflictResult.entity.getPendingPassiveEvents(in: self)
            })
        }
            .map { $0.execute(in: self) }
        
        return mainEventResults + reactionEventResults
    }
    
    //TODO: hook it in
    open func give(item: Storable, to entity: Entity) -> Event {
        
        let exchange = ItemExchange(exchangeType: .target, requiresInitiatorOwnItem: false, removesItemFromInitiator: false, item: item)
        let targeting = Targeting.init(.oneself, .always)
        
        let collect = Ability(name: "", components: [
            exchange,
            targeting
        ], shouldUseDefaults: true, cooldown: nil)
        
        let event = Event(category: .itemExchangeOnly, initiator: entity, ability: collect, rpSpace: self)
        return event
    }
    
    open func getEntities() -> [Entity] {
        return teams.values
            .flatMap { $0.entities }
    }
    
    open func getEnemies(of entity: Entity) -> [Entity] {
        return teams.values
            .filter { $0.id != entity.teamId }
            .flatMap { $0.entities }
    }
    
    open func getFriends(of entity: Entity) -> [Entity] {
        return teams.values
            .filter { $0.id == entity.teamId }
            .flatMap { $0.entities }
    }
    
    public func resetCooldown() { /* noop */ }

}
