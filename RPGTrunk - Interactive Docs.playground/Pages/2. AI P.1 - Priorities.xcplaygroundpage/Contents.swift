//: [Previous](@previous)
import Foundation
import XCPlayground
import RPGTrunk
import RPGTrunkDemo
/*:
# Basic AI

Depending on your own use case, you may have a way of deciding which actions to take. More than likely, however, if you are making an RPG-type game of any scale you will have some level of AI controlling enemies

*/

//: Let's start by recreating the foundation from our basic conflict example
let entity1 = Entity(Stats(["hp": 50]))
let entity2 = Entity(Stats(["hp": 50]))
let dmgComponent = Component(Stats(["damage": 3]))
let attack = Ability(["components": [dmgComponent]])
//: This time, instead of creating an event manually though, let's ask our entity to tell us what it wants to do. Entites have a queue of priorities that they execute. A new Entity starts with an empty queue though, so let's fix that.
let attackPriority = Priority(ability: attack, conditionals: nil)
entity1.priorities.append(attackPriority)
//: That's pretty easy to follow. We've created a Priority which basically says "Attack under any conditions" and appended it to entity1's priority queue. 

//: Now let's ask our entity to think
var nextEvent:Event? = entity1.think()
nextEvent // returns nil

//: Hmm, it returned nil. Why is that? Well, this is possible when it has no target or no qualifying priorities. We know we just added a priority that passes under any conditions though, so it must be the missing target
entity1.target = entity2

//: Now let's try again
nextEvent = entity1.think()
nextEvent // returns Event

//: We've gotten an Event back this time, so let's execute it!
let event = Event(initiator: entity1, targets:[entity2], ability:attack)
performEvent(event)
//: We see that Entity2 has lost 3 hit points
entity1.stats.hp
entity2.stats.hp

//: [Next](@next)
      
      
  
