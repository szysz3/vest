import Foundation

/// @mockable
public protocol BondPlannerRepository: Sendable {
    func fetchBondPlanner(query: BondPlannerQuery?) async throws -> BondPlannerData
    func updateBondPlannerSettings(_ settings: BondPlannerSettings) async throws -> BondPlannerSettings
}
