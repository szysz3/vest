import Foundation
import Core

@MainActor
public final class PortfolioViewModel: ObservableObject {
    @Published private(set) var state: ViewState<PortfolioState, ViewModelError> = .idle

    public nonisolated init() {}

    func loadIfNeeded() async {
        guard state.isIdle else { return }
        await load()
    }

    func load() async {
        state = .loading
        state = .loaded(PortfolioState())
    }
}

public struct PortfolioState: Equatable, Sendable {
    public init() {}
}
