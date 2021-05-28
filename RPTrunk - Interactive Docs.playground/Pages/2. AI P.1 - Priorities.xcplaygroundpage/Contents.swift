//: [Previous](@previous)
import Foundation
import RPTrunk
import RPTrunkDemo
import XCPlayground
/*:
 # Basic AI

 Depending on your own use case, you may have a way of deciding which actions to take. More than likely, however, if you are making an RPG-type game of any scale you will have some level of AI controlling enemies

 */

//: Let's start by recreating the foundation from our basic conflict example
let entity1 = Entity(["hp": 50])
let entity2 = Entity(["hp": 50])
let dmgComponent = Stats(["damage": 3])
let attack = Ability(name: "Attack", components: [dmgComponent])
//: This time, instead of creating an event manually though, let's ask our entity to tell us what it wants to do. Entites have a queue of priorities that they execute. A new Entity starts with an empty queue though, so let's fix that.

entity1.addExecutableAbility(attack, conditional: .always)
//: That's pretty easy to follow. We've created a Priority which basically says "Attack under any conditions" and appended it to entity1's priority queue.

//: Now let's ask our entity to think
let moment = Moment(delta: 1)
var nextEvents: [Event] = entity1.tick(moment)
nextEvents // empty array

//: Hmm, it returned nil. Why is that? Well, this is possible when it has no target or no qualifying priorities. We know we just added a priority that passes under any conditions though, so it must be the missing target
entity1.targets = [entity2]

//: Now let's try again
nextEvents = entity1.tick(moment)
nextEvents // returns an array with an RPEvent

//: We've gotten an RPEvent back this time, so let's execute it!
nextEvents.first?.execute()
//: We see that Entity2 has lost 3 hit points
entity1["hp"]
entity2["hp"]

//: [Next](@next)
