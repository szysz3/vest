import Testing
@testable import Presentation

@MainActor
@Test func portfolioViewModelInitialState() {
    let viewModel = PortfolioViewModel()
    #expect(viewModel.state.isIdle)
}

@MainActor
@Test func historyViewModelInitialState() {
    let viewModel = HistoryViewModel()
    #expect(viewModel.state.isIdle)
}
