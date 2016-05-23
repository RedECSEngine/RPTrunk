
//: [Previous](@previous)
import Foundation
import XCPlayground
import RPTrunk
import RPTrunkDemo
/*:
 # The *AI* object
 
 
 */

//: Let's start by recreating the foundation from our basic AI example
let entity1 = Entity(["hp": 50])
let entity2 = Entity(["hp": 50])

let dmgComponent = StatsComponent(["damage": 5])

//: ##### Our basic attack
let attack = BasicAbility(name:"Attack", components: [dmgComponent])
let attackPriority = Priority(ability: attack, conditionals: nil)

//: ##### The Finishing Blow
let finishingBlow = BasicAbility(name:"Finishing Blow", components: [dmgComponent, dmgComponent, dmgComponent]) // triple damage

//: Only execute this attack when targat below 20% hp
let lowHPCondition = Conditional("target.hp% < 20")
let fbPriority = Priority(ability: finishingBlow, conditionals: [lowHPCondition])

//: Set our finishing blow priority ahead of the basic attack
entity1.priorities = [
    fbPriority,
    attackPriority
]

entity1.target = entity2
/*:
 We know we can ask entity for events with `Entity.think()` and then manually execute them ourselves, but that's a bit boring. We're ready to let our Entities do their own bidding at a regular interval.
 
 So let's create a battle and put our entities inside
 */
let battle = RPBattle()
battle.entities += [entity1, entity2]

//: It's going to be an unfair fight, but let's see what happens
for _ in 0..<10 {
    battle.tick()
    entity1["hp"] // stays at 50
    entity2["hp"] // loses 5 per tick, then by 15 under 20% hp
}

//: [Next](@next)



