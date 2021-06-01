//
//  ParserResultType.swift
//  
//
//  Created by Kyle Newsome on 2021-05-31.
//

import Foundation

public enum ParserResultType {
    case evaluationFunction(f: (ParserResultType, RPSpace) -> ParserResultType)
    case entityResult(entity: Id<Entity>)
    case statsResult(stats: Stats)
    case valueResult(ParserValueType)
//    case percentResult(value: Double)
//    case boolResult(value: Bool)
    case nothing
}

public enum ParserValueType {
    case rpValue(RPValue)
    case percent(Double)
    case bool(Bool)
    
    init(_ value: RPValue) {
        self = .rpValue(value)
    }
    
    init(_ value: Double) {
        self = .percent(value)
    }
    
    init(_ value: Bool) {
        self = .bool(value)
    }
    
    func canCompare(to otherValue: ParserValueType) -> Bool {
        switch (self, otherValue) {
        case (.rpValue, .rpValue), (.percent,.percent), (.bool, .bool):
            return true
        default:
            return false
        }
    }
}

extension ParserValueType: Comparable {
    public static func < (lhs: ParserValueType, rhs: ParserValueType) -> Bool {
        switch (lhs, rhs) {
        case let (.rpValue(lv), .rpValue(rv)):
            return lv < rv
        case let (.percent(lv),.percent(rv)):
            return lv < rv
        case let (.bool(lv), .bool(rv)):
            return (lv ? 1 : 0) < (rv ? 1 : 0)
        default:
            return false
        }
    }
    
}
