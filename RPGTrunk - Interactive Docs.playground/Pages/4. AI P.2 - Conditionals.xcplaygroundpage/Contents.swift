//: [Previous](@previous)
import Foundation
import RPGTrunk


let joe = Entity(Stats(["hp": 30]))

let conditional = buildConditional(getStat(joe, "hp"), isGreaterThan(20))

conditional()

joe.baseStats = Stats(["hp": 10])

conditional()

//: [Next](@next)