import Data
import Domain
import Factory

// Register repository implementations as singletons.
// Example:
//   public extension Container {
//       var itemsRepository: Factory<ItemsRepository> {
//           self { ItemsRepositoryImpl() }
//               .singleton
//       }
//   }
public extension Container {
    var transactionRepository: Factory<TransactionRepository> {
        self { TransactionRepositoryImpl(httpClient: HTTPClient()) }
            .singleton
    }

    var biometricRepository: Factory<BiometricRepository> {
        self { BiometricRepositoryImpl() }
            .singleton
    }
}
