// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SixNotes",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "SixNotes",
            path: "SixNotes"
        )
    ]
)
