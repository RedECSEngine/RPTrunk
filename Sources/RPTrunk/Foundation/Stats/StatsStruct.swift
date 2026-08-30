@attached(member, names: arbitrary)
@attached(extension, conformances: StatsType)
public macro StatsStruct() = #externalMacro(module: "RPTrunkMacros", type: "StatsStructMacro")
