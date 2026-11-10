import Foundation

/// @mockable
public protocol GetBondPlannerUseCaseProtocol: Sendable {
    func execute(query: BondPlannerQuery?) async throws -> BondPlannerData
}

public struct GetBondPlannerUseCase: GetBondPlannerUseCaseProtocol {
    private let repository: BondPlannerRepository

    public init(repository: BondPlannerRepository) {
        self.repository = repository
    }

    public func execute(query: BondPlannerQuery? = nil) async throws -> BondPlannerData {
        try await repository.fetchBondPlanner(query: query)
    }
}

/// @mockable
public protocol UpdateBondPlannerSettingsUseCaseProtocol: Sendable {
    func execute(_ settings: BondPlannerSettings) async throws -> BondPlannerSettings
}

public struct UpdateBondPlannerSettingsUseCase: UpdateBondPlannerSettingsUseCaseProtocol {
    private let repository: BondPlannerRepository

    public init(repository: BondPlannerRepository) {
        self.repository = repository
    }

    public func execute(_ settings: BondPlannerSettings) async throws -> BondPlannerSettings {
        try await repository.updateBondPlannerSettings(settings)
    }
}
