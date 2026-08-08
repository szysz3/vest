import Domain
import Foundation

public struct TransactionRepositoryImpl: TransactionRepository {
    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func fetchTransactions() async throws -> [Transaction] {
        try await httpClient.request(path: "/transactions")
    }

    public func fetchPortfolioDetails() async throws -> [AssetDetail] {
        let responses: [AssetDetailRemoteResponse] = try await httpClient.request(path: "/portfolio/details")
        return responses.compactMap { r in
            guard let assetType = AssetType(rawValue: r.assetType) else { return nil }
            return AssetDetail(
                assetType: assetType,
                details: r.details,
                currency: r.currency ?? "PLN",
                nominalAmount: r.nominalAmount ?? r.totalAmount,
                totalAmount: r.totalAmount,
                profitOrLoss: r.profitOrLoss ?? 0.0,
                profitOrLossPct: r.profitOrLossPct ?? 0.0,
                nominalAmountPLN: r.nominalAmountPLN ?? r.totalAmountPLN,
                totalAmountPLN: r.totalAmountPLN,
                profitOrLossPLN: r.profitOrLossPLN ?? 0.0
            )
        }
    }

    public func fetchStatementSyncStatus() async throws -> StatementSyncStatus {
        let remote: StatementSyncStatusRemoteResponse = try await httpClient.request(path: "/statements/status")
        return StatementSyncStatus(
            allUploaded: remote.allUploaded,
            uploadedCount: remote.uploadedCount,
            totalCount: remote.totalCount,
            lastSyncDate: remote.lastSyncDate,
            missingSlots: remote.missingSlots
        )
    }
}

private struct AssetDetailRemoteResponse: Decodable {
    let assetType: String
    let details: String
    let currency: String?
    let nominalAmount: Double?
    let totalAmount: Double
    let profitOrLoss: Double?
    let profitOrLossPct: Double?
    let nominalAmountPLN: Double?
    let totalAmountPLN: Double
    let profitOrLossPLN: Double?
}

private struct StatementSyncStatusRemoteResponse: Decodable {
    let allUploaded: Bool
    let uploadedCount: Int
    let totalCount: Int
    let lastSyncDate: String?
    let missingSlots: [String]
}
