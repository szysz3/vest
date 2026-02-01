import Testing
@testable import Core

@Test func viewStateIdle() {
    let state: ViewState<String, ViewModelError> = .idle
    #expect(state.isIdle)
    #expect(!state.isLoading)
    #expect(!state.isLoaded)
    #expect(!state.isFailed)
    #expect(state.data == nil)
    #expect(state.error == nil)
}

@Test func viewStateLoaded() {
    let state: ViewState<String, ViewModelError> = .loaded("Hello")
    #expect(state.isLoaded)
    #expect(state.data == "Hello")
}
