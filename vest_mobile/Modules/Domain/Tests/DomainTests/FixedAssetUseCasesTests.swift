import Foundation
import Testing
@testable import Domain

final class MockFixedAssetRepository: FixedAssetRepository, @unchecked Sendable {
    var assets: [FixedAsset] = []
    var didDeleteId: String?

    func fetchFixedAssets() async throws -> [FixedAsset] {
        assets
    }

    func createFixedAsset(_ draft: FixedAssetDraft) async throws -> FixedAsset {
        let asset = FixedAsset(
            id: UUID().uuidString,
            assetType: draft.assetType,
            details: draft.details,
            amount: draft.amount,
            currency: draft.currency,
            amountPLN: draft.amount
        )
        assets.append(asset)
        return asset
    }

    func updateFixedAsset(id: String, draft: FixedAssetDraft) async throws -> FixedAsset {
        guard let index = assets.firstIndex(where: { $0.id == id }) else {
            throw DomainError.unknown("Not found")
        }
        let updated = FixedAsset(
            id: id,
            assetType: draft.assetType,
            details: draft.details,
            amount: draft.amount,
            currency: draft.currency,
            amountPLN: draft.amount
        )
        assets[index] = updated
        return updated
    }

    func deleteFixedAsset(id: String) async throws {
        didDeleteId = id
        assets.removeAll(where: { $0.id == id })
    }
}

@Suite("Fixed Asset Use Cases Tests")
struct FixedAssetUseCasesTests {
    @Test func createFixedAssetSuccess() async throws {
        let repo = MockFixedAssetRepository()
        let useCase = CreateFixedAssetUseCase(repository: repo)

        let draft = FixedAssetDraft(assetType: .cash, details: "Savings", amount: 5000, currency: "PLN")
        let asset = try await useCase.execute(draft)

        #expect(asset.details == "Savings")
        #expect(asset.amount == 5000)
        #expect(asset.assetType == .cash)
        #expect(repo.assets.count == 1)
    }

    @Test func createFixedAssetValidationError() async throws {
        let repo = MockFixedAssetRepository()
        let useCase = CreateFixedAssetUseCase(repository: repo)

        let draft = FixedAssetDraft(assetType: .gold, details: "   ", amount: 1000, currency: "PLN")
        await #expect(throws: DomainError.self) {
            try await useCase.execute(draft)
        }
    }

    @Test func updateFixedAssetSuccess() async throws {
        let repo = MockFixedAssetRepository()
        let createUseCase = CreateFixedAssetUseCase(repository: repo)
        let updateUseCase = UpdateFixedAssetUseCase(repository: repo)

        let created = try await createUseCase.execute(FixedAssetDraft(assetType: .gold, details: "1 oz", amount: 2500, currency: "USD"))
        let updated = try await updateUseCase.execute(id: created.id, draft: FixedAssetDraft(assetType: .gold, details: "1 oz Krugerrand", amount: 2600, currency: "USD"))

        #expect(updated.details == "1 oz Krugerrand")
        #expect(updated.amount == 2600)
    }

    @Test func deleteFixedAssetSuccess() async throws {
        let repo = MockFixedAssetRepository()
        let createUseCase = CreateFixedAssetUseCase(repository: repo)
        let deleteUseCase = DeleteFixedAssetUseCase(repository: repo)

        let created = try await createUseCase.execute(FixedAssetDraft(assetType: .cash, details: "Safe", amount: 1000, currency: "PLN"))
        #expect(repo.assets.count == 1)

        try await deleteUseCase.execute(id: created.id)
        #expect(repo.didDeleteId == created.id)
        #expect(repo.assets.isEmpty)
    }
}
