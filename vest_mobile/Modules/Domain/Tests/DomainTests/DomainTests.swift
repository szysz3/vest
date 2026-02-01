import Foundation
import Testing
@testable import Domain

@Test func domainErrorDescription() {
    let error = DomainError.networkError("timeout")
    #expect(error.errorDescription == "Network error: timeout")
}
