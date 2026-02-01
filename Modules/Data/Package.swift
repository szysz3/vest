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
