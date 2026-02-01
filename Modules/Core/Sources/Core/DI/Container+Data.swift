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
