// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// HOW TO ADD A NEW PACKAGE:
// 1. Add the repo URL to `dependencies` below, e.g.:
//        .package(url: "https://github.com/Org/Repo.git", from: "1.0.0"),
// 2. Add the product to the target's `dependencies`, e.g.:
//        .product(name: "ProductName", package: "Repo"),
// 3. In your Swift code: `import ProductName`

let package = Package(
    name: "AppDependencies",
    platforms: [.iOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AppDependencies",
            targets: ["AppDependencies"]
        ),
    ],
    dependencies: [

    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AppDependencies",
            dependencies: [

            ]
        ),
    ]
)
