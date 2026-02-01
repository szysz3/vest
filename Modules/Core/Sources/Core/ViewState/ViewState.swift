public enum ViewState<Success: Equatable & Sendable, Failure: Error & Equatable & Sendable>: Equatable, Sendable {
    case idle
    case loading
    case loaded(Success)
    case failed(Failure)

    public var isIdle: Bool { if case .idle = self { return true }; return false }
    public var isLoading: Bool { if case .loading = self { return true }; return false }
    public var isLoaded: Bool { if case .loaded = self { return true }; return false }
    public var isFailed: Bool { if case .failed = self { return true }; return false }

    public var data: Success? { if case .loaded(let data) = self { return data }; return nil }
    public var error: Failure? { if case .failed(let error) = self { return error }; return nil }
}
