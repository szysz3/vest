import Domain
import Foundation

public struct BondPlannerRepositoryImpl: BondPlannerRepository {
    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func fetchBondPlanner(query: BondPlannerQuery? = nil) async throws -> BondPlannerData {
        var params: [String: String] = [:]
        if let q = query {
            if let tm = q.targetMonthly {
                params["target_monthly"] = String(tm)
            }
            if let hy = q.horizonYears {
                params["horizon_years"] = String(hy)
            }
            if let b = q.budget {
                params["budget"] = String(b)
            }
            if let fam = q.includeFamilyBonds {
                params["include_family_bonds"] = fam ? "true" : "false"
            }
            if let inf = q.inflationRate {
                params["inflation_rate"] = String(inf)
            }
            if let nbp = q.nbpRate {
                params["nbp_rate"] = String(nbp)
            }
            if let rm = q.referenceMonth {
                params["reference_month"] = String(rm)
            }
        }

        return try await httpClient.request(
            path: "/bonds/planner",
            method: .GET,
            queryParameters: params.isEmpty ? nil : params
        )
    }

    public func updateBondPlannerSettings(_ settings: BondPlannerSettings) async throws -> BondPlannerSettings {
        try await httpClient.request(
            path: "/bonds/planner/settings",
            method: .PUT,
            parameters: settings
        )
    }
}
