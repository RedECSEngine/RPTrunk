public protocol RPItemDefining: Codable, Equatable, Sendable {
    associatedtype Metadata: Codable & Equatable & Sendable

    var code: RPReferenceCode { get }
    var displayName: String? { get }
    var tags: String? { get }
    var equipmentSlotCode: String? { get }
    var maxNumberOfOptionalStats: Int? { get }
    var metadata: Metadata? { get }

    var statCells: [String: String] { get }
}
