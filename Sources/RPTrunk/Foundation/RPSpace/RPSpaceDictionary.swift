//
//  File.swift
//  File
//
//  Created by Kyle Newsome on 2021-08-15.
//

public protocol RPSpaceDictionary: RPSpace {
    var entities: [RPEntityId: RPEntity<Self>] { get set }
    var teams: [RPTeamId: RPTeam<Self>] { get set }
    var pendingGameMasterEvents: [RPEvent<Self>] { get set }
}

extension RPSpaceDictionary {
    public func allEntities() -> Dictionary<RPEntityId, RPEntity<Self>>.Keys {
        entities.keys
    }

    public func allTeams() -> Dictionary<RPTeamId, RPTeam<Self>>.Keys  {
        teams.keys
    }

    public func allPendingGameMasterEvents() -> [RPEvent<Self>] {
        pendingGameMasterEvents
    }

    public func entityById(_ id: RPEntityId) -> RPEntity<Self>? {
        entities[id]
    }
    public func teamById(_ id: RPTeamId) -> RPTeam<Self>? {
        teams[id]
    }

    public mutating func addEntity(_ entity: RPEntity<Self>) {
        assert(entities[entity.id] == nil, "attempting to add entity that already exists in this space")
        entities[entity.id] = entity
    }

    public mutating func queueGameMasterEvent(_ event: RPEvent<Self>) {
        pendingGameMasterEvents.append(event)
    }

    public mutating func removeGameMasterEvent(id: RPEventId) {
        pendingGameMasterEvents.removeAll(where: { $0.id == id })
    }

    public mutating func modifyEntity(id: RPEntityId, perform: (inout RPEntity<Self>, Self) -> Void) {
        guard var entity = entities[id] else { return }
        perform(&entity, self)
        entities[id] = entity
    }

    public mutating func modifyTeam(id: RPTeamId, perform: (inout RPTeam<Self>, Self) -> Void) {
        guard var team = teams[id] else { return }
        perform(&team, self)
        teams[id] = team
    }

    public mutating func setTeams(_ newTeams: [RPTeam<Self>]) {
        var teamDict: [RPTeamId: RPTeam<Self>] = [:]
        newTeams.forEach { team in
            teamDict[team.id] = team
        }
        teams = teamDict
    }
}
