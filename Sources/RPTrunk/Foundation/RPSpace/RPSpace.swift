public typealias RPBodyId = String
public typealias RPTeamId = String
public typealias RPItemId = String
public typealias RPEventId = String
public typealias RPReferenceCode = String

public protocol RPMetadata: Codable & Equatable {}
public struct EmptyMetadataDictionary: RPMetadata, Sendable {
    public init() {}
}

public protocol RPSpace: Codable {

    associatedtype Stats: StatsType

    associatedtype BodyMetadata: RPMetadata = EmptyMetadataDictionary
    associatedtype ItemMetadata: RPMetadata = EmptyMetadataDictionary
    associatedtype AbilityMetadata: RPMetadata = EmptyMetadataDictionary

    typealias Body = RPBody<Self>
    associatedtype BodySequence: Sequence where BodySequence.Element == RPBodyId

    typealias Team = RPTeam<Self>
    associatedtype TeamSequence: Sequence where TeamSequence.Element == RPTeamId

    typealias ActiveItem = RPActiveItem<Self>

    static var statTypes: Set<String> { get }

    static var actionImpairingStatuses: Set<RPStatusCode> { get }

    /// How fast time passes for a body's own clocks — its global cooldown, its
    /// ability cooldowns and its threat decay. A haste effect belongs here.
    static func timeMultiplier(for body: RPBody<Self>) -> Double

    /// How fast time passes for one status effect held by a body. Separate from
    /// the body's own rate because RPTrunk cannot know whether a conformance
    /// wants haste to shorten its damage-over-time effects too — and the answer
    /// may differ per effect, hence the code.
    static func timeMultiplier(for body: RPBody<Self>, statusEffect code: RPReferenceCode) -> Double

    static func createDefaultBody(cache: RPCache<Self>) -> Body
    
    /// Where we calculate any relationship between stats to determine to final values
    /// e.g. where we calculate how stamina translates to HP
    /// or any other kinds of specialized game state that could impact final stats
    static func fullyResolvedStats(for stats: Self.Stats) -> Self.Stats

    /// How any interaction between to bodies in resolves.
    /// Events contain all the data necessary to calculate an end result
    static func resolveConflict(
        _ event: RPEvent<Self>,
        in rpSpace: Self,
        target: RPBodyId,
        conflict: Stats
    ) -> RPConflictResult<Self>

    /// How events translate into threat between bodies. Declared as a
    /// requirement so conformances can customize it; the default
    /// implementation produces no threat, leaving the system dormant.
    static func resolveThreatChanges(
        for eventResult: RPEventResult<Self>,
        in rpSpace: Self
    ) -> [RPThreatChange]

    func bodyById(_ id: RPBodyId) -> Body?
    func teamById(_ id: RPTeamId) -> Team?

    func allBodies() -> BodySequence
    func allTeams() -> TeamSequence
    func allPendingGameMasterEvents() -> [RPEvent<Self>]

    mutating func addBody(_ body: Body)
    mutating func setTeams(_ newTeams: [Team])
    mutating func queueGameMasterEvent(_ event: RPEvent<Self>)
    mutating func removeGameMasterEvent(id: RPEventId)

    mutating func modifyBody(id: RPBodyId, perform: (inout Body, Self) -> Void)
    mutating func modifyTeam(id: RPTeamId, perform: (inout Team, Self) -> Void)

}

public extension RPSpace {
    
    static var statTypes: Set<String> { Set(Stats.dynamicKeys.keys) }

    static var actionImpairingStatuses: Set<RPStatusCode> { [] }

    static func timeMultiplier(for body: RPBody<Self>) -> Double { 1 }

    static func timeMultiplier(for body: RPBody<Self>, statusEffect code: RPReferenceCode) -> Double { 1 }

    static func createDefaultBody(cache: RPCache<Self>) -> Body {
        Body()
    }
    
    static func fullyResolvedStats(for rpBody: RPBody<Self>) -> Stats {
        fullyResolvedStats(for: rpBody.cumulativeStats())
    }
    
    func getEnemies(of bodyId: RPBodyId) -> Set<RPBodyId> {
        guard let body = bodyById(bodyId),
              let teamId = body.teamId,
              let team = teamById(teamId)
        else {
            return []
        }

        return team.enemies.reduce(Set()) {
            accumulated, enemyTeamId -> Set<RPBodyId> in

            guard let enemies = teamById(enemyTeamId)?.bodies else {
                return accumulated
            }
            return accumulated.union(enemies)
        }
    }
    
    func getFriends(of bodyId: RPBodyId) -> Set<RPBodyId> {
        guard let body = bodyById(bodyId),
              let teamId = body.teamId,
              let team = teamById(teamId)
        else {
            return []
        }
        return team.bodies.union(getAllies(of: bodyId))
    }
    
    func getAllies(of bodyId: RPBodyId) -> Set<RPBodyId> {
        guard let body = bodyById(bodyId),
              let teamId = body.teamId,
              let team = teamById(teamId)
        else {
            return []
        }
        
        return team.allies.reduce(Set()) {
            accumulated, allyTeamId -> Set<RPBodyId> in
            
            guard let enemies = teamById(allyTeamId)?.bodies else {
                return accumulated
            }
            return accumulated.union(enemies)
        }
    }
}

extension RPSpace {
    public func allTeamedBodyIds() -> [RPBodyId] {
        var seen: Set<RPBodyId> = []
        return allTeams()
            .compactMap(teamById)
            .flatMap(\.bodies)
            .filter { seen.insert($0).inserted }
    }

    public mutating func tick(_ moment: RPMoment) {
        allTeamedBodyIds()
            .forEach {
                modifyBody(id: $0) { e, _ in
                    e.tick(moment)
                }
            }
    }

    public func getPendingEvents() -> [RPEvent<Self>] {
        allPendingGameMasterEvents() +
        getAllPendingPassiveEvents() +
        getAllPendingStatusEffectEvents() +
        getAllPendingExecutableEvents()
    }

    public func getAllPendingPassiveEvents() -> [RPEvent<Self>] {
        allTeamedBodyIds()
            .compactMap(bodyById)
            .flatMap { $0.getPendingPassiveEvents(in: self) }
    }

    /// Periodic events emitted by active status effects (heal/damage over time,
    /// e.g. Regen and Bleed). Without this, status effects tick internally but
    /// their per-tick events are never collected, so only the ability's initial
    /// application is felt.
    public func getAllPendingStatusEffectEvents() -> [RPEvent<Self>] {
        allTeamedBodyIds()
            .compactMap(bodyById)
            .flatMap { $0.getPendingStatusEffectEvents(in: self) }
    }

    public func getAllPendingExecutableEvents() -> [RPEvent<Self>] {
        allTeamedBodyIds()
            .compactMap(bodyById)
            .flatMap { $0.getPendingExecutableEvents(in: self) }
    }

    public mutating func performEvents(_ events: [RPEvent<Self>]) -> [RPEventResult<Self>] {
        events.forEach { event in
            self.removeGameMasterEvent(id: event.id)
        }

        let mainEventResults = events
            .flatMap { event -> [RPEvent<Self>] in
                switch event.category {
                case .standardConflict:
                    event.resetInitiatorCooldowns(in: &self)
                case .periodicEffect, .itemExchangeOnly:
                    break
                }
                return [event]
            }
            .map { $0.execute(in: &self) }
        
        let reactionEventResults = mainEventResults.flatMap {
            eventResult -> [RPEvent<Self>] in
            eventResult.effects.flatMap {
                conflictResult -> [RPEvent<Self>] in
                bodyById(conflictResult.body)?.getPendingPassiveEvents(in: self) ?? []
            }
        }
        .map { $0.execute(in: &self) }

        return mainEventResults + reactionEventResults
    }

}

public struct RPItemTransfer: Codable, Equatable {
    public let itemId: RPItemId
    public let code: RPReferenceCode
    public let amount: Int
    public let from: RPBodyId?
    public let to: RPBodyId

    public init(itemId: RPItemId, code: RPReferenceCode, amount: Int, from: RPBodyId?, to: RPBodyId) {
        self.itemId = itemId
        self.code = code
        self.amount = amount
        self.from = from
        self.to = to
    }
}

extension RPSpace {
    @discardableResult
    public mutating func receiveItem(
        _ incoming: ActiveItem,
        to recipientId: RPBodyId,
        from sourceId: RPBodyId? = nil
    ) -> [RPItemTransfer] {
        guard incoming.amount > 0, bodyById(recipientId) != nil else {
            return []
        }
        modifyBody(id: recipientId) { e, _ in
            var remaining = incoming.amount
            for index in e.inventory.indices {
                guard remaining > 0 else { break }
                guard e.inventory[index].code == incoming.code else { continue }
                let capacity = e.inventory[index].remainingCapacity ?? remaining
                guard capacity > 0 else { continue }
                let moved = Swift.min(remaining, capacity)
                e.inventory[index].amount += moved
                remaining -= moved
            }
            if remaining > 0 {
                var newStack = incoming
                newStack.amount = remaining
                e.inventory.append(newStack)
            }
        }
        return [RPItemTransfer(
            itemId: incoming.id,
            code: incoming.code,
            amount: incoming.amount,
            from: sourceId,
            to: recipientId
        )]
    }

    @discardableResult
    public mutating func transferItem(id: RPItemId, from sourceId: RPBodyId, to recipientId: RPBodyId) -> [RPItemTransfer] {
        guard sourceId != recipientId, let source = bodyById(sourceId) else { return [] }
        guard let outgoing = (source.inventory + source.equipment.wornItems).first(where: { $0.id == id }) else {
            return []
        }
        modifyBody(id: sourceId) { e, _ in
            e.inventory.removeAll { $0.id == id }
            e.equipment.unequip(itemId: id)
        }
        return receiveItem(outgoing, to: recipientId, from: sourceId)
    }

    @discardableResult
    public mutating func transferAllItems(from sourceId: RPBodyId, to recipientId: RPBodyId) -> [RPItemTransfer] {
        guard sourceId != recipientId, let source = bodyById(sourceId) else { return [] }
        let outgoing = source.inventory + source.equipment.wornItems
        modifyBody(id: sourceId) { e, _ in
            e.inventory = []
            e.equipment.unequipAll()
        }
        return outgoing.flatMap { receiveItem($0, to: recipientId, from: sourceId) }
    }

    /// Moves a carried item out of the inventory and into an equipment slot.
    /// Fails when the body is not carrying `id`, the item has no
    /// `equipmentSlotCode`, or its slot is already full.
    @discardableResult
    public mutating func equipItem(id: RPItemId, on bodyId: RPBodyId) -> Bool {
        guard let body = bodyById(bodyId),
              let item = body.inventory.first(where: { $0.id == id }),
              body.equipment.canEquip(item)
        else {
            return false
        }
        modifyBody(id: bodyId) { e, _ in
            e.inventory.removeAll { $0.id == id }
            e.equipment.equip(item)
        }
        return true
    }

    /// Moves a worn item out of its equipment slot and back into the inventory.
    @discardableResult
    public mutating func unequipItem(id: RPItemId, on bodyId: RPBodyId) -> Bool {
        guard bodyById(bodyId)?.equipment.wornItems.contains(where: { $0.id == id }) == true else {
            return false
        }
        modifyBody(id: bodyId) { e, _ in
            guard let removed = e.equipment.unequip(itemId: id) else { return }
            e.inventory.append(removed)
        }
        return true
    }

    public func collectAllEvent(from sourceId: RPBodyId, to recipientId: RPBodyId) -> RPEvent<Self> {
        RPEvent(
            category: .itemExchangeOnly,
            initiator: sourceId,
            ability: RPAbility<Self>(
                code: "collect",
                fragments: [RPFragment(itemExchange: RPItemExchange(kind: .transferAll))]
            ),
            targets: [recipientId],
            rpSpace: self
        )
    }
}
