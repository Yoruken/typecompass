// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TypeCompass",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "TypeCompass", targets: ["TypeCompass"])],
    targets: [
        .target(name: "TypeCompassCore"),
        .executableTarget(name: "TypeCompass", dependencies: ["TypeCompassCore"]),
        .testTarget(name: "TypeCompassCoreTests", dependencies: ["TypeCompassCore"])
    ]
)
