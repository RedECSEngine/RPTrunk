//: [Previous](@previous)
import RPTrunk
import RPTrunkDemo
import XCPlayground
/*:
 # Basic AI

 Depending on your own use case, you may have a way of deciding which actions to take. More than likely, however, if you are making an RPG-type game of any scale you will have some level of AI controlling enemies

 */

//: Let's start by recreating the foundation from our basic conflict example
let body1 = Body(["hp": 50])
let body2 = Body(["hp": 50])
let dmgComponent = Stats(["damage": 3])
let attack = Ability(name: "Attack", components: [dmgComponent])
//: This time, instead of creating an event manually though, let's ask our body to tell us what it wants to do. Bodies have a queue of priorities that they execute. A new Body starts with an empty queue though, so let's fix that.

body1.addExecutableAbility(attack, conditional: .always)
//: That's pretty easy to follow. We've created a Priority which basically says "Attack under any conditions" and appended it to body1's priority queue.

//: Now let's ask our body to think
let moment = Moment(delta: 1)
var nextEvents: [Event] = body1.tick(moment)
nextEvents // empty array

//: Hmm, it returned nil. Why is that? Well, this is possible when it has no target or no qualifying priorities. We know we just added a priority that passes under any conditions though, so it must be the missing target
body1.targets = [body2]

//: Now let's try again
nextEvents = body1.tick(moment)
nextEvents // returns an array with an RPEvent

//: We've gotten an RPEvent back this time, so let's execute it!
nextEvents.first?.execute()
//: We see that Body2 has lost 3 hit points
body1["hp"]
body2["hp"]

//: [Next](@next)
