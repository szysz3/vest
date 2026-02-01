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
        ]),
        .testTarget(name: "PresentationTests", dependencies: [
            "Presentation",
            .product(name: "Domain", package: "Domain"),
            .product(name: "Core", package: "Core")
        ])
    ]
)
