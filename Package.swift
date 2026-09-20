// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DotBuddy",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "DotBuddyCore",
            path: "DotBuddy",
            sources: [
                "Alias.swift",
                "AliasFileManager.swift",
                "CommandConflictChecker.swift",
                "EnvVariable.swift",
                "EnvFileManager.swift",
                "ShellProfileDetector.swift",
                "SSHHost.swift",
                "SSHConfigFileManager.swift",
                "KnownHost.swift",
                "KnownHostsFileManager.swift",
            ]
        ),
        .testTarget(
            name: "DotBuddyTests",
            dependencies: ["DotBuddyCore"],
            path: "Tests"
        ),
    ]
)
