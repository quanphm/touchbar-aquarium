// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TouchBarAquarium",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "aquarium-render", targets: ["AquariumRender"]),
        .executable(name: "AquariumBar", targets: ["AquariumBar"]),
        .executable(name: "aquarium-checks", targets: ["AquariumChecks"]),
    ],
    targets: [
        // Pure, headless, fully unit-testable. Imports no UI framework.
        .target(name: "AquariumCore"),

        // Dev tool: renders the sim to PNG so the art can be reviewed without a GUI.
        .executableTarget(name: "AquariumRender", dependencies: ["AquariumCore"]),

        // AppKit adapter: shows the same frames in a preview window and the Touch Bar.
        .executableTarget(name: "AquariumBar", dependencies: ["AquariumCore", "TouchBarPrivate"]),

        // Objective-C shim for Apple's private system-modal Touch Bar API.
        // Calls are resolved at runtime; nothing private is linked at build time.
        .target(name: "TouchBarPrivate", path: "Sources/TouchBarPrivate"),

        // Self-contained checks. XCTest needs full Xcode; this runs with
        // Command Line Tools alone.
        .executableTarget(name: "AquariumChecks", dependencies: ["AquariumCore"]),
    ]
)
