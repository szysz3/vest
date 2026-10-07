import Foundation

/// @mockable
public protocol GetFixedAssetsUseCaseProtocol: Sendable {
    func execute() async throws -> [FixedAsset]
}

public struct GetFixedAssetsUseCase: GetFixedAssetsUseCaseProtocol {
    private let repository: FixedAssetRepository

    public init(repository: FixedAssetRepository) {
        self.repository = repository
    }

    public func execute() async throws -> [FixedAsset] {
        try await repository.fetchFixedAssets()
    }
}

/// @mockable
public protocol CreateFixedAssetUseCaseProtocol: Sendable {
    func execute(_ draft: FixedAssetDraft) async throws -> FixedAsset
}

public struct CreateFixedAssetUseCase: CreateFixedAssetUseCaseProtocol {
    private let repository: FixedAssetRepository

    public init(repository: FixedAssetRepository) {
        self.repository = repository
    }

    public func execute(_ draft: FixedAssetDraft) async throws -> FixedAsset {
        guard !draft.details.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw DomainError.validationError("Asset name cannot be empty")
        }
        guard draft.amount >= 0 else {
            throw DomainError.validationError("Amount cannot be negative")
        }
        return try await repository.createFixedAsset(draft)
    }
}

/// @mockable
public protocol UpdateFixedAssetUseCaseProtocol: Sendable {
    func execute(id: String, draft: FixedAssetDraft) async throws -> FixedAsset
}

public struct UpdateFixedAssetUseCase: UpdateFixedAssetUseCaseProtocol {
    private let repository: FixedAssetRepository

    public init(repository: FixedAssetRepository) {
        self.repository = repository
    }

    public func execute(id: String, draft: FixedAssetDraft) async throws -> FixedAsset {
        guard !draft.details.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw DomainError.validationError("Asset name cannot be empty")
        }
        guard draft.amount >= 0 else {
            throw DomainError.validationError("Amount cannot be negative")
        }
        return try await repository.updateFixedAsset(id: id, draft: draft)
    }
}

/// @mockable
public protocol DeleteFixedAssetUseCaseProtocol: Sendable {
    func execute(id: String) async throws
}

public struct DeleteFixedAssetUseCase: DeleteFixedAssetUseCaseProtocol {
    private let repository: FixedAssetRepository

    public init(repository: FixedAssetRepository) {
        self.repository = repository
    }

    public func execute(id: String) async throws {
        try await repository.deleteFixedAsset(id: id)
    }
}
