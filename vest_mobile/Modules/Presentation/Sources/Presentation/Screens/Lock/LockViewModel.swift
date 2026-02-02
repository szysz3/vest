import Foundation
import Core
import Domain

@MainActor
public final class LockViewModel: ObservableObject {
    @Published public private(set) var isUnlocked: Bool = false
    @Published private(set) var error: String?

    private let authenticateWithBiometricsUseCase: AuthenticateWithBiometricsUseCaseProtocol

    public nonisolated init(authenticateWithBiometricsUseCase: AuthenticateWithBiometricsUseCaseProtocol) {
        self.authenticateWithBiometricsUseCase = authenticateWithBiometricsUseCase
    }

    func authenticate() async {
        error = nil
        do {
            try await authenticateWithBiometricsUseCase.execute()
            isUnlocked = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
