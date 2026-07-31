//
//  File.swift
//  File
//
//  Created by Kyle Newsome on 2021-08-15.
//

public protocol RPSpaceDictionary: RPSpace {
    var bodies: [RPBodyId: RPBody<Self>] { get set }
    var teams: [RPTeamId: RPTeam<Self>] { get set }
    var pendingGameMasterEvents: [RPEvent<Self>] { get set }
}

extension RPSpaceDictionary {
    public func allBodies() -> Dictionary<RPBodyId, RPBody<Self>>.Keys {
        bodies.keys
    }

    public func allTeams() -> Dictionary<RPTeamId, RPTeam<Self>>.Keys  {
        teams.keys
    }

    public func allPendingGameMasterEvents() -> [RPEvent<Self>] {
        pendingGameMasterEvents
    }

    public func bodyById(_ id: RPBodyId) -> RPBody<Self>? {
        bodies[id]
    }
    public func teamById(_ id: RPTeamId) -> RPTeam<Self>? {
        teams[id]
    }

    public mutating func addBody(_ body: RPBody<Self>) {
        assert(bodies[body.id] == nil, "attempting to add body that already exists in this space")
        bodies[body.id] = body
    }

    public mutating func queueGameMasterEvent(_ event: RPEvent<Self>) {
        pendingGameMasterEvents.append(event)
    }

    public mutating func removeGameMasterEvent(id: RPEventId) {
        pendingGameMasterEvents.removeAll(where: { $0.id == id })
    }

    public mutating func modifyBody(id: RPBodyId, perform: (inout RPBody<Self>, Self) -> Void) {
        guard var body = bodies[id] else { return }
        perform(&body, self)
        bodies[id] = body
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
