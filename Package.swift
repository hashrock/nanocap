// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "nanocap",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "nanocap", path: "Sources/nanocap")
    ],
    swiftLanguageModes: [.v5]
)
