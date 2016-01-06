import Foundation
import XCPlayground
import RPGTrunk
import RPGTrunkDemo

//: # A basic Entity conflict
/*:
### 1. Build up your entities and ablities
To demonstrate a basic conflict, first we start by creating two entities with some initial hit points..
*/
let entity1 = Entity(Stats(["hp": 50]))
let entity2 = Entity(Stats(["hp": 50]))

/*: 
Next, we need to create an ability that an entity can execute.
Creating an ability starts by first creating a Generic component with properties

In this example we'll make a component with some damage
*/
let dmgComponent = Component(Stats(["damage": 3]))
//: Now we can create our ability with the damage component. An ability is always made up of one or more components
let attack = Ability(["components": [dmgComponent]])

/*: 
### 2. Create an event and perform it

That's all the groundwork necessary for the set up .Now we just need to create an event that combines our entities and ability into a conflict
*/
let event = Event(initiator: entity1, targets:[entity2], ability:attack)
performEvent(event)
//: We see that Entity2 has lost 3 hit points
entity1.stats.hp
entity2.stats.hp
//: This is just one way we can build up RPG functionality and execute conflicts between entities

//: [Next](@next)
