// swift-tools-version: 5.10
import PackageDescription

// Swift 5 language mode keeps the macOS 13+ target compatible with Xcode 15.4 and newer.
var products: [Product] = [
    .library(name: "CodexLimitGuardCore", targets: ["CodexLimitGuardCore"])
]

var targets: [Target] = [
    .target(
        name: "CodexLimitGuardCore",
        path: "Sources/CodexLimitGuardCore"
    ),
    .testTarget(
        name: "CodexLimitGuardCoreTests",
        dependencies: ["CodexLimitGuardCore"],
        path: "Tests/CodexLimitGuardCoreTests"
    )
]

#if os(macOS)
products.append(.executable(name: "CodexLimitGuard", targets: ["CodexLimitGuardMac"]))
targets.append(
    .executableTarget(
        name: "CodexLimitGuardMac",
        dependencies: ["CodexLimitGuardCore"],
        path: "Sources/CodexLimitGuardMac"
    )
)
#endif

let package = Package(
    name: "CodexLimitGuard",
    platforms: [.macOS(.v13)],
    products: products,
    targets: targets,
    swiftLanguageVersions: [.v5]
)
