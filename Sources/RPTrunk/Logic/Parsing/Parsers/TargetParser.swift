//
//  TargetParser.swift
//  
//
//  Created by Kyle Newsome on 2021-05-31.
//

import Foundation
import Parsing

func getTarget(_ input: ParserResultType, in rpSpace: RPSpace) -> ParserResultType {
    if case let .entityResult(e) = input, let target = rpSpace.entities[e]?.getTarget() {
        return .entityResult(entity: target)
    }
    return .nothing
}

let targetParser = Parsing
    .StartsWith<Substring>("target")
    .map { _ in
        ParserResultType.evaluationFunction(f: getTarget)
    }
