
//: [Previous](@previous)
import Foundation
import RPTrunk
import RPTrunkDemo
import XCPlayground
/*:
 # The *AI* object

 */

//: Let's start by recreating the foundation from our basic AI example
let entity1 = Entity(["hp": 50])
let entity2 = Entity(["hp": 50])

let dmgComponent = Stats(["damage": 5])

//: ##### Our basic attack
let attack = Ability(name: "Attack", components: [dmgComponent])

//: ##### The Finishing Blow
let finishingBlow = Ability(name: "Finishing Blow", components: [dmgComponent, dmgComponent, dmgComponent]) // triple damage

//: Only execute this attack when targat below 20% hp
entity1.addExecutableAbility(finishingBlow, conditional: "target.hp% < 20")
entity1.addExecutableAbility(attack, conditional: .always)

entity1.targets = [entity2]
/*:
 We know we can ask entity for events with `Entity.think()` and then manually execute them ourselves, but that's a bit boring. We're ready to let our Entities do their own bidding at a regular interval.

 So let's create a battle and put our entities inside
 */
let battle = Battle()
battle.teams += [Team(entities: [entity1]), Team(entities: [entity2])]

//: It's going to be an unfair fight, but let's see what happens
for _ in 0 ..< 10 {
    battle.newMoment()
    entity1["hp"] // stays at 50
    entity2["hp"] // loses 5 per tick, then by 15 under 20% hp
    print(entity2["hp"])
}

//: [Next](@next)
