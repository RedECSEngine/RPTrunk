
//: [Previous](@previous)
import RPTrunk
import RPTrunkDemo
import XCPlayground
/*:
 # The *AI* object

 */

//: Let's start by recreating the foundation from our basic AI example
let body1 = Body(["hp": 50])
let body2 = Body(["hp": 50])

let dmgComponent = Stats(["damage": 5])

//: ##### Our basic attack
let attack = Ability(name: "Attack", components: [dmgComponent])

//: ##### The Finishing Blow
let finishingBlow = Ability(name: "Finishing Blow", components: [dmgComponent, dmgComponent, dmgComponent]) // triple damage

//: Only execute this attack when targat below 20% hp
body1.addExecutableAbility(finishingBlow, conditional: "target.hp% < 20")
body1.addExecutableAbility(attack, conditional: .always)

body1.targets = [body2]
/*:
 We know we can ask body for events with `Body.think()` and then manually execute them ourselves, but that's a bit boring. We're ready to let our Bodies do their own bidding at a regular interval.

 So let's create a battle and put our bodies inside
 */
let battle = Battle()
battle.teams += [Team(bodies: [body1]), Team(bodies: [body2])]

//: It's going to be an unfair fight, but let's see what happens
for _ in 0 ..< 10 {
    battle.newMoment()
    body1["hp"] // stays at 50
    body2["hp"] // loses 5 per tick, then by 15 under 20% hp
    print(body2["hp"])
}

//: [Next](@next)
