import Testing
import Domain
@testable import Presentation

@MainActor
@Test func portfolioViewModelInitialState() {
    let viewModel = PortfolioViewModel(
        getPortfolioSummaryUseCase: StubGetPortfolioSummaryUseCase(),
        getStatementSyncStatusUseCase: StubGetStatementSyncStatusUseCase()
    )
    #expect(viewModel.state.isIdle)
}

private struct StubGetPortfolioSummaryUseCase: GetPortfolioSummaryUseCaseProtocol {
    func execute() async throws -> PortfolioSummary {
        PortfolioSummary(nominalAmount: 0, totalAmount: 0, profitOrLoss: 0, profitOrLossPct: 0, assets: [])
    }
}

private struct StubGetStatementSyncStatusUseCase: GetStatementSyncStatusUseCaseProtocol {
    func execute() async throws -> StatementSyncStatus {
        StatementSyncStatus(allUploaded: true, uploadedCount: 2, totalCount: 2, lastSyncDate: "2026-08-07", missingSlots: [])
    }
}
