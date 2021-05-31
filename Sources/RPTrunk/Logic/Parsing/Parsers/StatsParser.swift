//
//  StatsParser.swift
//  
//
//  Created by Kyle Newsome on 2021-05-31.
//

import Foundation
import Parsing

func getStat(_ type: String, usePercent: Bool) -> (ParserResultType) -> ParserResultType {
    { input in
        if case let .entityResult(e) = input {
            let currentValue = e[type]
            if usePercent {
                let percent: Double = floor(Double(currentValue) / Double(e.stats[type]) * 100)
                return .valueResult(.percent(percent))
            }
            return .valueResult(.rpValue(currentValue))
        }
        return .nothing
    }
}

let statParser = Parsing.AnyParser<Substring, ParserResultType> { input in
    var type = input
    var usePercent = false

    if input.last == "%" {
        type.removeLast()
        usePercent = true
    }

    guard RPGameEnvironment.statTypes.contains(String(type)) else {
        return nil
    }

    let function = getStat(String(type), usePercent: usePercent)

    return ParserResultType.evaluationFunction(f: function)
}
