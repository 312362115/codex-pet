// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexPetCompanion",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PetCompanion", targets: ["PetCompanion"]),
        .executable(name: "CodexPetCompanion", targets: ["CodexPetCompanion"])
    ],
    targets: [
        .target(name: "PetCompanion"),
        .executableTarget(
            name: "CodexPetCompanion",
            dependencies: ["PetCompanion"]
        ),
        .testTarget(
            name: "PetCompanionTests",
            dependencies: ["PetCompanion"]
        )
    ]
)
