// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DuoWorkspace",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "DuoCore", targets: ["DuoCore"]),
        .library(name: "DuoHost", targets: ["DuoHost"]),
        .executable(name: "duo-probe", targets: ["DuoProbe"])
    ],
    targets: [
        .target(name: "DuoCore"),
        .target(name: "VirtualDisplayBridge", publicHeadersPath: "include",
                cSettings: [.unsafeFlags(["-fobjc-arc"])],
                linkerSettings: [.linkedFramework("Foundation"), .linkedFramework("CoreGraphics")]),
        .target(name: "DuoMicrophoneBridge", publicHeadersPath: "include",
                linkerSettings: [.linkedFramework("CoreAudio"), .linkedFramework("CoreFoundation")]),
        .target(name: "DuoHost", dependencies: ["DuoCore", "VirtualDisplayBridge", "DuoMicrophoneBridge"]),
        .executableTarget(name: "DuoProbe", dependencies: ["DuoHost", "DuoCore"]),
        .testTarget(name: "DuoCoreTests", dependencies: ["DuoCore"]),
        .testTarget(name: "DuoMediaTests", dependencies: ["DuoCore", "DuoHost", "DuoMicrophoneBridge"])
    ],
    swiftLanguageModes: [.v5]
)
