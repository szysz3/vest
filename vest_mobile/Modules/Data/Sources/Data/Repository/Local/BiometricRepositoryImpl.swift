import Domain
import Foundation
import LocalAuthentication

public struct BiometricRepositoryImpl: BiometricRepository {
    public init() {}

    public func authenticate() async throws {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw DomainError.unknown(error?.localizedDescription ?? "Biometric authentication not available")
        }

        do {
            try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock vest to access your portfolio"
            )
        } catch {
            throw DomainError.unknown(error.localizedDescription)
        }
    }
}
