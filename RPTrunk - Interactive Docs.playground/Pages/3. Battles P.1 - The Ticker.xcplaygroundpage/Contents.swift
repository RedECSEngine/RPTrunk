//: [Previous](@previous)
import Foundation
import XCPlayground
import RPTrunk
import RPTrunkDemo
/*:
# The *Battle* object

While it is certainly possible (and maybe even desirable) to manually build up and execute all your own events, the Battle object is intended to make life easier by faciliating a few common RPG needs such as:

1. A time system
2. RPEvent queueing and execution with before and after callbacks
3. References to all entities participating in combat
4. AI thought faciliation

*/

//: Let's start by recreating the foundation from our basic AI example
let entity1 = Entity(["hp": 50])
let entity2 = Entity(["hp": 50])

let dmgComponent = Stats(["damage": 3])
let attack = Ability(name:"Attack", components: [dmgComponent])

entity1.addExecutableAbility(attack, conditional: .always)
entity1.targets = [entity2]
/*:
We know we can ask entity for events with `Entity.think()` and then manually execute them ourselves, but that's a bit boring. We're ready to let our Entities do their own bidding at a regular interval.

So let's create a battle and put our entities inside
*/
let battle = Battle()
let team1 = Team(entities: [entity1])
let team2 = Team(entities: [entity2])
battle.teams = [team1, team2]

//: It's going to be an unfair fight, but let's see what happens
for _ in 0..<10 {
    
    battle.newMoment()
    entity1["hp"] // stays at 50
    entity2["hp"] // loses 3 per tick
}

//: [Next](@next)



