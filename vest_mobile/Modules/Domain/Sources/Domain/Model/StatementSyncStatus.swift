import Foundation

public struct StatementSyncStatus: Equatable, Sendable {
    public let allUploaded: Bool
    public let uploadedCount: Int
    public let totalCount: Int
    public let lastSyncDate: String?
    public let missingSlots: [String]

    public init(
        allUploaded: Bool,
        uploadedCount: Int,
        totalCount: Int,
        lastSyncDate: String?,
        missingSlots: [String]
    ) {
        self.allUploaded = allUploaded
        self.uploadedCount = uploadedCount
        self.totalCount = totalCount
        self.lastSyncDate = lastSyncDate
        self.missingSlots = missingSlots
    }
}
