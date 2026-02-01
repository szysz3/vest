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
