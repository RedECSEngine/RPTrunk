//: [Previous](@previous)
import Foundation
import XCPlayground
import RPGTrunk
import RPGTrunkDemo
/*:
# The *Battle* object

While it is certainly possible (and maybe even desirable) to manually build up and execute all your own events, the Battle object is intended to make life easier by faciliating a few common RPG needs such as:

1. A time system
2. Event queueing and execution with before and after callbacks
3. References to all entities participating in combat
4. AI thought faciliation

*/

//: Let's start by recreating the foundation from our basic AI example
let entity1 = Entity(Stats(["hp": 50]))
let entity2 = Entity(Stats(["hp": 50]))
let dmgComponent = Component(Stats(["damage": 3]))
let attack = Ability(["components": [dmgComponent]])
let attackPriority = Priority(ability: attack, conditionals: nil)
entity1.priorities.append(attackPriority)
entity1.target = entity2
/*:
We know we can ask entity for events with `Entity.think()` and then manually execute them ourselves, but that's a bit boring. We're ready to let our Entities do their own bidding at a regular interval.

So let's create a battle and put our entities inside
*/
let battle = Battle()
battle.entities += [entity1, entity2]

//: It's going to be an unfair fight, but let's see what happens
for _ in 0..<10 {
    battle.tick()
    entity1.stats.hp // stays at 50
    entity2.stats.hp // loses 3 per tick
}

//: [Next](@next)



