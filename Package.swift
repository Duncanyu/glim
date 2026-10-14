// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Glim",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ColorEditor", targets: ["ColorEditor"])],
    targets: [
        .executableTarget(name: "ColorEditor"),
        .testTarget(name: "ColorEditorTests", dependencies: ["ColorEditor"])
    ]
)
