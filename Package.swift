// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClamshellToggle",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ClamshellToggle", path: "Sources/ClamshellToggle")
    ]
)
