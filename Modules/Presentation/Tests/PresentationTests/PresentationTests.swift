import Testing
import Domain
@testable import Presentation

@MainActor
@Test func portfolioViewModelInitialState() {
    let viewModel = PortfolioViewModel(
        getPortfolioSummaryUseCase: StubGetPortfolioSummaryUseCase(),
        addTransactionUseCase: StubAddTransactionUseCase(),
        getTransactionFormOptionsUseCase: StubGetTransactionFormOptionsUseCase()
    )
    #expect(viewModel.state.isIdle)
}

@MainActor
@Test func historyViewModelInitialState() {
    let viewModel = HistoryViewModel(getTransactionsUseCase: StubGetTransactionsUseCase())
    #expect(viewModel.state.isIdle)
}

private struct StubGetPortfolioSummaryUseCase: GetPortfolioSummaryUseCaseProtocol {
    func execute() async throws -> PortfolioSummary {
        PortfolioSummary(totalAmount: 0, assets: [])
    }
}

private struct StubAddTransactionUseCase: AddTransactionUseCaseProtocol {
    func execute(transaction: Transaction) async throws {}
}

private struct StubGetTransactionFormOptionsUseCase: GetTransactionFormOptionsUseCaseProtocol {
    func execute() async throws -> TransactionFormOptions {
        TransactionFormOptions.empty
    }
}

private struct StubGetTransactionsUseCase: GetTransactionsUseCaseProtocol {
    func execute() async throws -> [Transaction] { [] }
}
