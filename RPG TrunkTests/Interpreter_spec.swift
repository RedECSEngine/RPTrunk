//
//  Interpreter_spec.swift
//  RPG Trunk
//
//  Created by Kyle Newsome on 2016-01-16.
//  Copyright © 2016 Kyle Newsome. All rights reserved.
//

import XCTest
import Nimble
@testable import RPGTrunk

class Interpreter_spec: XCTestCase {
    let entity = RPEntity(["hp": 40])
    let enemy = RPEntity(["hp": 20])
    
    override func setUp() {
        super.setUp()
        
        entity.target = enemy
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func test_getTarget_shouldReturnTheEntityTarget() {
        let result = getTarget(entity)
        expect(result == PropertyResultType.Entity(entity: self.enemy)).to(beTrue())
    }
    
    func test_entityParsing() {
        let result = entity.parse(ArraySlice(["hp"]))
        expect(result).to(equal(40))
        
        let result2 = entity.parse(ArraySlice(["target", "hp"]))
        expect(result2).to(equal(20))
    }
    
    func test_stringInterpretation(){
        let entityPredicate = try! interpretStringCondition("hp > target.hp")
        
        expect(entityPredicate(self.entity)).to(equal(true))
        expect(entityPredicate(self.enemy)).to(equal(false))
    }
}
    