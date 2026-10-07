# Mobile App Architecture Template

A production-ready, modular **Clean Architecture** template for iOS applications built with **Swift 6**, **iOS 18+**, **SwiftUI**, **XcodeGen**, and **Swift Package Manager (SPM)**.

---

## 1. Architectural Overview

The application follows Clean Architecture principles divided into decoupled local Swift Packages. Dependencies flow inward toward the pure **Domain** layer.

```
┌────────────────────────────────────────────────────────┐
│                      App Target                        │
│            (Entry point, Lifecycle, DI Boot)           │
└──────────────┬──────────────────────────┬──────────────┘
               │                          │
               ▼                          ▼
┌──────────────────────────────┐  ┌──────────────────────┐
│         Presentation         │  │         Core         │
│ (SwiftUI Views, ViewModels,  │  │  (DI Container,      │
│   Design Tokens, Navigation) │  │   ViewState, Utils)  │
└──────────────┬───────────────┘  └──────┬───────┬───────┘
               │                         │       │
               ▼                         ▼       │
┌──────────────────────────────┐                 │
│            Domain            │◄────────────────┘
│  (Entities, Use Cases,       │
│   Repository Protocols)      │◄────────────────┐
└──────────────────────────────┘                 │
               ▲                                 │
               │                                 │
┌──────────────┴───────────────┐                 │
│             Data             │─────────────────┘
│  (API Client, DTOs,          │
│   Repository Implementations)│
└──────────────────────────────┘
```

### Dependency Rules
* **Domain**: Pure Swift. Zero external framework dependencies (no SwiftUI, no UIKit, no third-party networking/storage). Contains enterprise entities, business rules (Use Cases), and repository protocols (`/// @mockable`).
* **Data**: Depends *only* on **Domain**. Handles network communication, disk storage, database persistence, DTO serialization/deserialization, and mapping DTOs to Domain models.
* **Core**: Depends on **Domain**, **Data**, and DI framework (**Factory**). Contains global DI registrations, cross-layer state abstractions (`ViewState<T, E>`), shared extensions, and validators.
* **Presentation**: Depends on **Domain**, **Core**, and DI framework (**Factory**). Contains SwiftUI views, `@MainActor` ViewModels, UI design system tokens, formatters, and navigation.
* **App Target**: Top-level application wrapper connecting Xcode bundle configuration, entitlements, launch screens, and the root navigation view.

---

## 2. Directory Layout

```
<ProjectName>_mobile/
├── project.yml                          # Declarative XcodeGen configuration
├── scripts/
│   └── generate_mocks.sh                # Automated mock generation using Mockolo
├── App/
│   ├── Info.plist
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   ├── Config.json                  # Runtime configuration (API Base URL, etc.)
│   │   └── <ProjectName>.entitlements
│   └── Sources/
│       └── <ProjectName>App.swift       # @main App entry point
└── Modules/
    ├── Domain/
    │   ├── Package.swift
    │   ├── Sources/Domain/
    │   │   ├── Model/                   # Pure business entities (Sendable, Equatable)
    │   │   ├── Repository/              # Repository protocols with `/// @mockable`
    │   │   ├── UseCase/                 # Single-responsibility business use cases
    │   │   └── Error/                   # Domain errors (DomainError)
    │   └── Tests/DomainTests/           # Swift Testing suite (@Test, #expect)
    ├── Data/
    │   ├── Package.swift
    │   ├── Sources/Data/
    │   │   ├── Config/                  # Network configuration & endpoint routing
    │   │   ├── Model/                   # DTOs / Remote / Local schema responses
    │   │   └── Repository/
    │   │       ├── Remote/              # REST / GraphQL / WebSocket implementations
    │   │       ├── Local/               # Cache / Keychain / Local database
    │   │       └── Base/                # Base HTTPClient & Network engines
    │   └── Tests/DataTests/
    ├── Core/
    │   ├── Package.swift
    │   ├── Sources/Core/
    │   │   ├── DI/                      # Factory container extensions (Container+Domain.swift, etc.)
    │   │   ├── ViewState/               # ViewState<Success, Failure>, ViewModelError
    │   │   ├── Validator/               # Input validators
    │   │   └── Extensions/              # Foundation & standard library utilities
    │   └── Tests/CoreTests/
    └── Presentation/
        ├── Package.swift
        ├── Sources/Presentation/
        │   ├── Base/                    # Base components & view modifiers
        │   ├── DesignSystem/            # Colors, Typography, Spacing, Assets
        │   ├── Navigation/              # NavigationTabContainer, Router, Coordinator
        │   ├── Screens/
        │   │   └── <FeatureName>/
        │   │       ├── <FeatureName>Screen.swift
        │   │       └── <FeatureName>ViewModel.swift
        │   ├── Views/                   # Reusable UI widgets & cards
        │   ├── Formatters/              # Date / Currency / Number formatters
        │   └── DI/                      # Container+Presentation.swift (ViewModel factories)
        └── Tests/PresentationTests/
```

---

## 3. Project Configuration Template (`project.yml`)

Save this as `project.yml` in your project root:

```yaml
name: YourApp
options:
  bundleIdPrefix: com.yourapp
  deploymentTarget:
    iOS: "18.0"
  xcodeVersion: "16.0"
  generateEmptyDirectories: true

packages:
  Domain:
    path: Modules/Domain
  Data:
    path: Modules/Data
  Core:
    path: Modules/Core
  Presentation:
    path: Modules/Presentation
  Factory:
    url: https://github.com/hmlongco/Factory.git
    from: "2.3.0"

targets:
  YourApp:
    type: application
    platform: iOS
    sources:
      - App/Sources
      - path: App/Resources
        buildPhase: resources
      - path: App/Resources/Config.json
        buildPhase: resources
    dependencies:
      - package: Domain
      - package: Data
      - package: Core
      - package: Presentation
      - package: Factory
    info:
      path: App/Info.plist
      properties:
        UILaunchScreen: {}
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
        CFBundleDisplayName: YourApp
    settings:
      base:
        SWIFT_VERSION: "6.0"
        GENERATE_INFOPLIST_FILE: YES
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: "1"
        PRODUCT_BUNDLE_IDENTIFIER: com.yourapp.app
        SWIFT_STRICT_CONCURRENCY: complete
      configs:
        Debug:
          SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG
        Release:
          SWIFT_ACTIVE_COMPILATION_CONDITIONS: ""
```

---

## 4. Package Manifest Templates (`Package.swift`)

### `Modules/Domain/Package.swift`
```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Domain",
    platforms: [.iOS(.v18), .macOS(.v13)],
    products: [
        .library(name: "Domain", targets: ["Domain"])
    ],
    targets: [
        .target(name: "Domain"),
        .testTarget(name: "DomainTests", dependencies: ["Domain"])
    ]
)
```

### `Modules/Data/Package.swift`
```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Data",
    platforms: [.iOS(.v18), .macOS(.v13)],
    products: [
        .library(name: "Data", targets: ["Data"])
    ],
    dependencies: [
        .package(path: "../Domain")
    ],
    targets: [
        .target(name: "Data", dependencies: [
            .product(name: "Domain", package: "Domain")
        ]),
        .testTarget(name: "DataTests", dependencies: [
            "Data",
            .product(name: "Domain", package: "Domain")
        ])
    ]
)
```

### `Modules/Core/Package.swift`
```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.iOS(.v18), .macOS(.v13)],
    products: [
        .library(name: "Core", targets: ["Core"])
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../Data"),
        .package(url: "https://github.com/hmlongco/Factory.git", from: "2.3.0")
    ],
    targets: [
        .target(name: "Core", dependencies: [
            .product(name: "Domain", package: "Domain"),
            .product(name: "Data", package: "Data"),
            .product(name: "Factory", package: "Factory")
        ]),
        .testTarget(name: "CoreTests", dependencies: [
            "Core",
            .product(name: "Domain", package: "Domain"),
            .product(name: "Data", package: "Data")
        ])
    ]
)
```

### `Modules/Presentation/Package.swift`
```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Presentation",
    platforms: [.iOS(.v18), .macOS(.v13)],
    products: [
        .library(name: "Presentation", targets: ["Presentation"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Domain"),
        .package(url: "https://github.com/hmlongco/Factory.git", from: "2.3.0")
    ],
    targets: [
        .target(name: "Presentation", dependencies: [
            .product(name: "Core", package: "Core"),
            .product(name: "Domain", package: "Domain"),
            .product(name: "Factory", package: "Factory")
        ], resources: [
            .process("Resources")
        ]),
        .testTarget(name: "PresentationTests", dependencies: [
            "Presentation",
            .product(name: "Domain", package: "Domain"),
            .product(name: "Core", package: "Core")
        ])
    ]
)
```

---

## 5. Core Code Patterns & Implementation Standards

### A. Generic View State Abstraction (`Modules/Core/.../ViewState.swift`)
Standardize asynchronous screen states across the entire application:

```swift
public enum ViewState<Success: Equatable & Sendable, Failure: Error & Equatable & Sendable>: Equatable, Sendable {
    case idle
    case loading
    case loaded(Success)
    case failed(Failure)

    public var isIdle: Bool { if case .idle = self { return true }; return false }
    public var isLoading: Bool { if case .loading = self { return true }; return false }
    public var isLoaded: Bool { if case .loaded = self { return true }; return false }
    public var isFailed: Bool { if case .failed = self { return true }; return false }

    public var data: Success? { if case .loaded(let data) = self { return data }; return nil }
    public var error: Failure? { if case .failed(let error) = self { return error }; return nil }
}
```

---

### B. Domain Repository Protocol & Use Case
Always mark protocols with `/// @mockable` for automated mock generation:

```swift
// Modules/Domain/Sources/Domain/Repository/ItemRepository.swift
import Foundation

/// @mockable
public protocol ItemRepository: Sendable {
    func fetchItems() async throws -> [Item]
}
```

```swift
// Modules/Domain/Sources/Domain/UseCase/GetItemsUseCase.swift
import Foundation

/// @mockable
public protocol GetItemsUseCaseProtocol: Sendable {
    func execute() async throws -> [Item]
}

public struct GetItemsUseCase: GetItemsUseCaseProtocol {
    private let repository: ItemRepository

    public init(repository: ItemRepository) {
        self.repository = repository
    }

    public func execute() async throws -> [Item] {
        try await repository.fetchItems()
    }
}
```

---

### C. Data Repository Implementation & DTO Mapping
Keep remote data models private to the repository file unless shared within the Data module:

```swift
// Modules/Data/Sources/Data/Repository/Remote/ItemRepositoryImpl.swift
import Domain
import Foundation

public struct ItemRepositoryImpl: ItemRepository {
    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func fetchItems() async throws -> [Item] {
        let responses: [ItemRemoteResponse] = try await httpClient.request(path: "/items")
        return responses.map { $0.toDomain() }
    }
}

private struct ItemRemoteResponse: Decodable {
    let id: String
    let name: String
    let value: Double

    func toDomain() -> Item {
        Item(id: id, name: name, value: value)
    }
}
```

---

### D. Dependency Injection Registrations (Factory)

```swift
// Modules/Core/Sources/Core/DI/Container+Data.swift
import Data
import Domain
import Factory

public extension Container {
    var httpClient: Factory<HTTPClient> {
        self { HTTPClientImpl() }.singleton
    }

    var itemRepository: Factory<ItemRepository> {
        self { ItemRepositoryImpl(httpClient: self.httpClient()) }
    }
}
```

```swift
// Modules/Core/Sources/Core/DI/Container+Domain.swift
import Domain
import Factory

public extension Container {
    var getItemsUseCase: Factory<GetItemsUseCaseProtocol> {
        self { GetItemsUseCase(repository: self.itemRepository()) }
    }
}
```

```swift
// Modules/Presentation/Sources/Presentation/DI/Container+Presentation.swift
import Core
import Domain
import Factory

public extension Container {
    var itemsViewModel: Factory<ItemsViewModel> {
        self { ItemsViewModel(getItemsUseCase: self.getItemsUseCase()) }
    }
}
```

---

### E. ViewModel & Screen Pattern (@Observable Macro)

With iOS 18+ and Swift 6, use Apple's native `@Observable` macro from `import Observation` rather than `ObservableObject` / `@Published`. This enables fine-grained view re-rendering, eliminates wrapper boilerplate, and integrates seamlessly with `@MainActor`.

```swift
// Modules/Presentation/Sources/Presentation/Screens/Items/ItemsViewModel.swift
import Foundation
import Observation
import Core
import Domain

@Observable
@MainActor
public final class ItemsViewModel {
    public private(set) var state: ViewState<ItemsState, ViewModelError> = .idle

    private let getItemsUseCase: GetItemsUseCaseProtocol

    public init(getItemsUseCase: GetItemsUseCaseProtocol) {
        self.getItemsUseCase = getItemsUseCase
    }

    public func loadIfNeeded() async {
        guard state.isIdle else { return }
        await load()
    }

    public func load() async {
        state = .loading
        do {
            let items = try await getItemsUseCase.execute()
            state = .loaded(ItemsState(items: items))
        } catch {
            state = .failed(ViewModelError(from: error))
        }
    }
}

public struct ItemsState: Equatable, Sendable {
    public let items: [Item]
    public init(items: [Item]) { self.items = items }
}
```

```swift
// Modules/Presentation/Sources/Presentation/Screens/Items/ItemsScreen.swift
import SwiftUI
import Core

public struct ItemsScreen: View {
    // With @Observable, no property wrapper like @ObservedObject is needed
    let viewModel: ItemsViewModel

    public init(viewModel: ItemsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
            case .loaded(let state):
                List(state.items) { item in
                    Text(item.name)
                }
            case .failed(let error):
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error.message))
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }
}
```

---

## 6. Automated Mock Generation Script (`scripts/generate_mocks.sh`)

```bash
#!/bin/bash
set -euo pipefail

# Mock generation script using Mockolo
# Usage:
#   ./scripts/generate_mocks.sh           # Generate mocks for all modules
#   ./scripts/generate_mocks.sh Domain    # Generate mocks for a specific module

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MODULES_DIR="$PROJECT_ROOT/Modules"

if ! command -v mockolo &> /dev/null; then
    echo "Error: mockolo is not installed. Install it with: brew install mockolo"
    exit 1
fi

generate_mocks() {
    local module="$1"
    local sources_dir="$MODULES_DIR/$module/Sources/$module"
    local tests_dir="$MODULES_DIR/$module/Tests/${module}Tests"
    local output_file="$tests_dir/Generated${module}Mocks.swift"

    if [ ! -d "$sources_dir" ]; then
        echo "Warning: Sources directory not found for $module, skipping."
        return
    fi

    mkdir -p "$tests_dir"

    local source_dirs=("$sources_dir")
    case "$module" in
        Data)
            source_dirs+=("$MODULES_DIR/Domain/Sources/Domain")
            ;;
        Core)
            source_dirs+=("$MODULES_DIR/Domain/Sources/Domain")
            source_dirs+=("$MODULES_DIR/Data/Sources/Data")
            ;;
        Presentation)
            source_dirs+=("$MODULES_DIR/Domain/Sources/Domain")
            source_dirs+=("$MODULES_DIR/Core/Sources/Core")
            ;;
    esac

    local src_args=""
    for dir in "${source_dirs[@]}"; do
        if [ -d "$dir" ]; then
            src_args="$src_args -s $dir"
        fi
    done

    echo "Generating mocks for $module..."
    mockolo $src_args -d "$output_file" --enable-args-history --mock-final
    echo "  -> $output_file"
}

if [ $# -eq 1 ]; then
    generate_mocks "$1"
else
    for module in Domain Data Core Presentation; do
        generate_mocks "$module"
    done
fi

echo "Mock generation complete."
```

---

## 7. Swift Testing Standards (`import Testing`)

Use Swift Testing framework instead of XCTest for all module tests:

```swift
import Foundation
import Testing
@testable import Domain

@Suite("Items Use Case Tests")
struct GetItemsUseCaseTests {
    @Test("Successfully fetches items")
    func fetchItemsSuccess() async throws {
        let mockRepo = ItemRepositoryMock()
        mockRepo.fetchItemsHandler = { [Item(id: "1", name: "Sample", value: 100)] }

        let useCase = GetItemsUseCase(repository: mockRepo)
        let result = try await useCase.execute()

        #expect(result.count == 1)
        #expect(result.first?.name == "Sample")
    }
}
```

---

## 8. Quickstart Checklist for New Projects

1. **Install Prerequisites**:
   ```bash
   brew install xcodegen mockolo
   ```
2. **Scaffold Directory Structure**:
   Create the directory tree according to [Section 2](#2-directory-layout).
3. **Add Manifests**:
   Place the `Package.swift` files in each module directory.
4. **Configure `project.yml`**:
   Adjust project name, bundle identifier prefix, and deployment target.
5. **Generate Xcode Project**:
   ```bash
   xcodegen generate
   ```
6. **Generate Test Mocks**:
   ```bash
   chmod +x scripts/generate_mocks.sh
   ./scripts/generate_mocks.sh
   ```
