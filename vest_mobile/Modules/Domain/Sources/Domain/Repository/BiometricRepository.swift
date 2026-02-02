import Foundation

/// @mockable
public protocol BiometricRepository: Sendable {
    func authenticate() async throws
}
