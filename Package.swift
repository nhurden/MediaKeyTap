// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "MediaKeyTap",
    products: [
        .library(name: "MediaKeyTap", targets: ["MediaKeyTap"]),
    ],
    targets: [
        .target(name: "MediaKeyTap", path: "MediaKeyTap"),
    ]
)
