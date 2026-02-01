import Domain
import Factory

// Register use case implementations.
// Example:
//   public extension Container {
//       var getItemsUseCase: Factory<GetItemsUseCaseProtocol> {
//           self {
//               GetItemsUseCase(repository: self.itemsRepository())
//           }
//       }
//   }
public extension Container {
    var getTransactionsUseCase: Factory<GetTransactionsUseCaseProtocol> {
        self {
            GetTransactionsUseCase(repository: self.transactionRepository())
        }
    }

    var addTransactionUseCase: Factory<AddTransactionUseCaseProtocol> {
        self {
            AddTransactionUseCase(repository: self.transactionRepository())
        }
    }

    var getTransactionFormOptionsUseCase: Factory<GetTransactionFormOptionsUseCaseProtocol> {
        self {
            GetTransactionFormOptionsUseCase(repository: self.transactionRepository())
        }
    }

    var getPortfolioSummaryUseCase: Factory<GetPortfolioSummaryUseCaseProtocol> {
        self {
            GetPortfolioSummaryUseCase(repository: self.transactionRepository())
        }
    }
}
