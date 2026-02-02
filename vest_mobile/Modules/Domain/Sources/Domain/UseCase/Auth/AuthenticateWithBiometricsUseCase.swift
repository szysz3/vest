import Foundation

/// @mockable
public protocol AuthenticateWithBiometricsUseCaseProtocol: Sendable {
    func execute() async throws
}

public struct AuthenticateWithBiometricsUseCase: AuthenticateWithBiometricsUseCaseProtocol {
    private let repository: BiometricRepository

    public init(repository: BiometricRepository) {
        self.repository = repository
    }

    public func execute() async throws {
        try await repository.authenticate()
    }
}
