public protocol RPCacheProvidable: AnyObject {
    associatedtype RP : RPSpace
    func getAbility(_ code: RPReferenceCode) throws -> RPAbility<RP>
    func getStatusEffect(_ code: RPReferenceCode) throws -> RPFragment<RP>
    func getFragment(_ code: RPReferenceCode) throws -> RPFragment<RP>
    func getLootTable(_ code: RPReferenceCode) throws -> RPLootTable<RP>
    func newBody(_ code: RPReferenceCode) throws -> RPBody<RP>
}
