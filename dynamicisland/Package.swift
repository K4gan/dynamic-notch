// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DynamicNotch",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "DynamicNotch",
            targets: ["DynamicNotch"]
        )
    ],
    targets: [
        .executableTarget(
            name: "DynamicNotch",
            dependencies: [],
            path: ".",
            sources: [
                "NotchApp.swift",
                "NotchWindow.swift",
                "NotchViewModel.swift",
                "ContentView.swift"
            ]
        )
    ]
)

