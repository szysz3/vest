import Testing
import Domain
import Core
@testable import Presentation

private final class StubFixedAssetRepository: FixedAssetRepository, @unchecked Sendable {
    var assets: [FixedAsset] = []
    var deletedId: String?

    func fetchFixedAssets() async throws -> [FixedAsset] {
        assets
    }

    func createFixedAsset(_ draft: FixedAssetDraft) async throws -> FixedAsset {
        let asset = FixedAsset(
            id: "asset_1",
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
        let updated = FixedAsset(
            id: id,
            assetType: draft.assetType,
            details: draft.details,
            amount: draft.amount,
            currency: draft.currency,
            amountPLN: draft.amount
        )
        return updated
    }

    func deleteFixedAsset(id: String) async throws {
        deletedId = id
        assets.removeAll(where: { $0.id == id })
    }
}

@Suite("FixedAssetViewModel Tests")
@MainActor
struct FixedAssetViewModelTests {
    @Test func addModeValidationAndSave() async throws {
        let repo = StubFixedAssetRepository()
        let createUseCase = CreateFixedAssetUseCase(repository: repo)
        let updateUseCase = UpdateFixedAssetUseCase(repository: repo)
        let deleteUseCase = DeleteFixedAssetUseCase(repository: repo)

        let vm = FixedAssetViewModel(
            mode: .add,
            createFixedAssetUseCase: createUseCase,
            updateFixedAssetUseCase: updateUseCase,
            deleteFixedAssetUseCase: deleteUseCase
        )

        #expect(!vm.isFormValid)
        #expect(!vm.mode.isEditing)

        vm.details = "Emergency Fund"
        vm.amountText = "15000"
        vm.assetType = .cash
        vm.currency = "PLN"

        #expect(vm.isFormValid)
        #expect(vm.parsedAmount == 15000.0)

        let success = await vm.save()
        #expect(success)
        #expect(repo.assets.count == 1)
        #expect(repo.assets.first?.details == "Emergency Fund")
    }

    @Test func editModePrepopulateAndSave() async throws {
        let repo = StubFixedAssetRepository()
        let createUseCase = CreateFixedAssetUseCase(repository: repo)
        let updateUseCase = UpdateFixedAssetUseCase(repository: repo)
        let deleteUseCase = DeleteFixedAssetUseCase(repository: repo)

        let vm = FixedAssetViewModel(
            mode: .edit(id: "asset_1"),
            initialAssetType: .gold,
            initialDetails: "1 oz Krugerrand",
            initialAmount: 2800.0,
            initialCurrency: "USD",
            createFixedAssetUseCase: createUseCase,
            updateFixedAssetUseCase: updateUseCase,
            deleteFixedAssetUseCase: deleteUseCase
        )

        #expect(vm.mode.isEditing)
        #expect(vm.assetType == .gold)
        #expect(vm.details == "1 oz Krugerrand")
        #expect(vm.amountText == "2800")
        #expect(vm.currency == "USD")
        #expect(vm.isFormValid)

        vm.amountText = "2900"
        let success = await vm.save()
        #expect(success)
    }

    @Test func editModeDelete() async throws {
        let repo = StubFixedAssetRepository()
        let asset = FixedAsset(id: "asset_delete", assetType: .cash, details: "Cash", amount: 100, currency: "PLN", amountPLN: 100)
        repo.assets = [asset]

        let createUseCase = CreateFixedAssetUseCase(repository: repo)
        let updateUseCase = UpdateFixedAssetUseCase(repository: repo)
        let deleteUseCase = DeleteFixedAssetUseCase(repository: repo)

        let vm = FixedAssetViewModel(
            mode: .edit(id: "asset_delete"),
            initialAssetType: .cash,
            initialDetails: "Cash",
            initialAmount: 100.0,
            initialCurrency: "PLN",
            createFixedAssetUseCase: createUseCase,
            updateFixedAssetUseCase: updateUseCase,
            deleteFixedAssetUseCase: deleteUseCase
        )

        let success = await vm.delete()
        #expect(success)
        #expect(repo.deletedId == "asset_delete")
        #expect(repo.assets.isEmpty)
    }
}
