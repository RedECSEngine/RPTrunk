public enum ParserResultType<RP: RPSpace> {
    case evaluationFunction(f: (ParserResultType, RPConditionContext, RP) -> ParserResultType)
    case bodyResult(body: RPBodyId)
    case statsResult(stats: RP.Stats)
    case valueResult(ParserValueType)
    case nothing
}
