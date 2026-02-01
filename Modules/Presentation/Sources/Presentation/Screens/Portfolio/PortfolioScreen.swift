import SwiftUI
import Core

struct PortfolioScreen: View {
    @StateObject var viewModel: PortfolioViewModel

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task { await viewModel.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
        case .loaded:
            Text("Portfolio")
                .font(.title)
        case .failed(let error):
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
        }
    }
}
