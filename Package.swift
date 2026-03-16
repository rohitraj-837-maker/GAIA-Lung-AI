// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "GAIA",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "GAIA",
            targets: ["GAIA"],
            bundleIdentifier: "com.rohitraj.GAIA",
            teamIdentifier: "YPMVGRJF7U",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            appCategory: .healthcareFitness
        )
    ],
    targets: [
        .executableTarget(
            name: "GAIA",
            path: "Sources",
            resources: [
                .copy("GAIA_Classifier.mlmodelc")
            ]
        )
    ]
)