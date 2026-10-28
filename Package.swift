// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Spellsheet",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Spellsheet", targets: ["Spellsheet"])
    ],
    targets: [
        .target(name: "SpellsheetCore"),
        .executableTarget(
            name: "Spellsheet",
            dependencies: ["SpellsheetCore"]
        ),
        .executableTarget(
            name: "SpellsheetChecks",
            dependencies: ["SpellsheetCore"]
        ),
    ]
)
