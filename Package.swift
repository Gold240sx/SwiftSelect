// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftSelect",
    platforms: [
        .iOS(.v13), .macOS(.v14), .tvOS(.v13), .watchOS(.v6), .visionOS(.v2)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftSelect",
            targets: ["SwiftSelect"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.15.0"),
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI.git", from: "3.1.3"),
        .package(url: "https://github.com/SDWebImage/SDWebImageSVGCoder.git", from: "1.8.0")
     ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
           name: "SwiftSelect",
           dependencies: [
             .product(name: "SDWebImage", package: "SDWebImage"),
             .product(name: "SDWebImageSwiftUI", package: "SDWebImageSwiftUI"),
             .product(name: "SDWebImageSVGCoder", package: "SDWebImageSVGCoder")
           ],
           path: "Sources/SwiftSelect"
         ),
        .testTarget(
            name: "SwiftSelectTests",
            dependencies: ["SwiftSelect"]
        ),
    ]
)
