// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BarcodeScanner",
    defaultLocalization: "en",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "BarcodeScanner",
            targets: ["BarcodeScanner"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BarcodeScanner",
            path: "Sources"
        ),
    ]
)
