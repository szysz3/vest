import Foundation

/// @mockable
public protocol FixedAssetRepository: Sendable {
    func fetchFixedAssets() async throws -> [FixedAsset]
    func createFixedAsset(_ draft: FixedAssetDraft) async throws -> FixedAsset
    func updateFixedAsset(id: String, draft: FixedAssetDraft) async throws -> FixedAsset
    func deleteFixedAsset(id: String) async throws
}
