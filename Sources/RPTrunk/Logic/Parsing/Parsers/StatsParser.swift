//
//  StatsParser.swift
//
//
//  Created by Kyle Newsome on 2021-05-31.
//


func getStat<RP: RPSpace>(_ stat: String, usePercent: Bool) -> (ParserResultType<RP>, RPConditionContext, RP) -> ParserResultType<RP> {
    { input, _, rpSpace in
        if case let .bodyResult(e) = input,
           let rpBody = rpSpace.bodyById(e) {
            let currentValue = rpBody[stat]
            if usePercent {
                let percent: Double = (Double(currentValue) / Double(RP.fullyResolvedStats(for: rpBody)[stat]) * 100).rounded()
                return .valueResult(.percent(percent))
            }
            return .valueResult(.rpValue(currentValue))
        }
        return .nothing
    }
}
