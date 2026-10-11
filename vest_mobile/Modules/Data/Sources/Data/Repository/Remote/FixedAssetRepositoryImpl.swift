import Domain
import Foundation

public struct FixedAssetRepositoryImpl: FixedAssetRepository {
    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func fetchFixedAssets() async throws -> [FixedAsset] {
        let responses: [FixedAssetRemoteResponse] = try await httpClient.request(path: "/fixed-assets")
        return responses.compactMap { $0.toDomain() }
    }

    public func createFixedAsset(_ draft: FixedAssetDraft) async throws -> FixedAsset {
        let payload = FixedAssetCreateRemoteRequest(
            assetType: draft.assetType.rawValue,
            details: draft.details,
            amount: draft.amount,
            currency: draft.currency,
            weightOz: draft.weightOz
        )
        let response: FixedAssetRemoteResponse = try await httpClient.request(
            path: "/fixed-assets",
            method: .POST,
            parameters: payload
        )
        guard let domain = response.toDomain() else {
            throw DomainError.decodingError
        }
        return domain
    }

    public func updateFixedAsset(id: String, draft: FixedAssetDraft) async throws -> FixedAsset {
        let payload = FixedAssetUpdateRemoteRequest(
            details: draft.details,
            amount: draft.amount,
            currency: draft.currency,
            weightOz: draft.weightOz
        )
        let response: FixedAssetRemoteResponse = try await httpClient.request(
            path: "/fixed-assets/\(id)",
            method: .PUT,
            parameters: payload
        )
        guard let domain = response.toDomain() else {
            throw DomainError.decodingError
        }
        return domain
    }

    public func deleteFixedAsset(id: String) async throws {
        try await httpClient.requestVoid(
            path: "/fixed-assets/\(id)",
            method: .DELETE
        )
    }
}

private struct FixedAssetRemoteResponse: Decodable {
    let id: String
    let assetType: String
    let details: String
    let amount: Double
    let currency: String
    let amountPLN: Double
    let weightOz: Double?

    func toDomain() -> FixedAsset? {
        guard let type = AssetType(rawValue: assetType) else { return nil }
        return FixedAsset(
            id: id,
            assetType: type,
            details: details,
            amount: amount,
            currency: currency,
            amountPLN: amountPLN,
            weightOz: weightOz
        )
    }
}

private struct FixedAssetCreateRemoteRequest: Encodable, Sendable {
    let assetType: String
    let details: String
    let amount: Double
    let currency: String
    let weightOz: Double?
}

private struct FixedAssetUpdateRemoteRequest: Encodable, Sendable {
    let details: String
    let amount: Double
    let currency: String
    let weightOz: Double?
}
