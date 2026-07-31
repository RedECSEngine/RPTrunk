import RPTrunk
import RPTrunkDemo
import XCPlayground

//: # A basic Body conflict
/*:
 ### 1. Build up your bodies and ablities
 To demonstrate a basic conflict, first we start by creating two bodies with some initial hit points..
 */
let body1 = Body(["hp": 50])
let body2 = Body(["hp": 50])

/*:
 Next, we need to create an ability that an body can execute.
 Creating an ability starts by first creating a Generic component with properties

 In this example we'll make a component with some damage
 */
let dmgComponent = Stats(["damage": 3])
//: Now we can create our ability with the damage component. An ability is always made up of one or more components
let attack = Ability(name: "Attack", components: [dmgComponent])
body1.targets = [body2]

/*:
 ### 2. Create an event and perform it

 That's all the groundwork necessary for the set up .Now we just need to create an event that combines our bodies and ability into a conflict
 */
let event = Event(initiator: body1, ability: attack)
let results = event.execute()
results.effects.forEach { print($0) }
//: We see that Body2 has lost 3 hit points
body1["hp"]
body2["hp"]
//: This is just one way we can build up RPG functionality and execute conflicts between bodies

//: [Next](@next)
