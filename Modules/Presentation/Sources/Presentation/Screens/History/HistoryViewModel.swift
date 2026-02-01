import Foundation
import Core

@MainActor
public final class HistoryViewModel: ObservableObject {
    @Published private(set) var state: ViewState<HistoryState, ViewModelError> = .idle

    public nonisolated init() {}

    func loadIfNeeded() async {
        guard state.isIdle else { return }
        await load()
    }

    func load() async {
        state = .loading
        state = .loaded(HistoryState())
    }
}

public struct HistoryState: Equatable, Sendable {
    public init() {}
}
