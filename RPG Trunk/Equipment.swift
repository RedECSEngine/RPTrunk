//
//  Equipment.swift
//  RPG Trunk
//
//  Created by Kyle Newsome on 2016-01-02.
//  Copyright © 2016 Kyle Newsome. All rights reserved.
//

import Foundation

public protocol Storable {
    var name:String {get}
}

public protocol Wearable: Storable, StatsContainer {
    var component:Component? {get set}
}

public class Item: Storable {
    public var name = "Unititled Item"
}

public class Armor: Wearable {
    public var name = "Unititled Armor"
    public var component:Component?
    public var stats:Stats {
        return component?.stats ?? Stats([:])
    }
}

public class Weapon: Wearable {
    public var name = "Unititled Weapon"
    public var component:Component?
    public var stats:Stats {
        return component?.stats ?? Stats([:])
    }
}

public struct Storage {
    let items:[Storable] = []
}
