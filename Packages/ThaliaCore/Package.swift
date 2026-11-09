// swift-tools-version: 6.0
import PackageDescription

// ThaliaCore: all of Thalia's logic that doesn't need Apple frameworks (Foundation only).
// Tested with Swift Testing on Linux in CI, so keep UIKit/SwiftUI/SwiftData out of here.
let package = Package(
    name: "ThaliaCore",
    platforms: [.iOS("26.0"), .macOS("26.0"), .watchOS("26.0")],
    products: [
        .library(name: "ThaliaCore", targets: ["ThaliaCore"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/BinisoftKit"),
    ],
    targets: [
        .target(
            name: "ThaliaCore",
            dependencies: [.product(name: "BinisoftKitCore", package: "BinisoftKit")]
        ),
        .testTarget(name: "ThaliaCoreTests", dependencies: ["ThaliaCore"]),
    ],
    swiftLanguageModes: [.v5]
)
