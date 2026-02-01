import Foundation

/// Protocol for async use cases with parameters
public protocol AsyncUseCase<Input, Output>: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    func execute(_ params: Input) async throws -> Output
}

/// Protocol for async use cases with no parameters
public protocol AsyncNoParamsUseCase<Output>: Sendable {
    associatedtype Output: Sendable
    func execute() async throws -> Output
}

/// Protocol for synchronous use cases with no parameters
public protocol SyncNoParamsUseCase<Output>: Sendable {
    associatedtype Output: Sendable
    func execute() -> Output
}
