// swift-tools-version: 6.0
import PackageDescription

// The shared core of Horariss, published for portfolio review.
//
// In the real project these modules are compiled twice: by Xcode for the iOS
// app and by Skip, which transpiles them to Kotlin and Jetpack Compose for the
// Android app. That is why the lower layers avoid UIKit entirely, and why
// platform-specific code lives behind `#if SKIP` / `#if !SKIP`.
//
// Left out on purpose: the store integration (StoreKit 2 and RevenueCat), the
// Firebase data layer, the Cloud Functions and every key or configuration file.
let package = Package(
    name: "Horariss",
    defaultLocalization: "es",
    platforms: [
        .iOS(.v18),
        // macOS is here so `swift test` runs on the host in about a second.
        .macOS(.v14)
    ],
    products: [
        .library(name: "HorarissModel", targets: ["HorarissModel"]),
        .library(name: "HorarissServicios", targets: ["HorarissServicios"]),
        .library(name: "HorarissUI", targets: ["HorarissUI"]),
        .library(name: "HorarissPDF", targets: ["HorarissPDF"])
    ],
    targets: [
        // Pure data model: no SwiftUI, no UIKit, so it compiles for Android as is.
        .target(name: "HorarissModel"),
        // Platform services that need a different implementation per platform:
        // local notifications (UserNotifications / AlarmManager), calendar sync
        // (EventKit) and the subscription plan math shown in the paywall.
        .target(name: "HorarissServicios", dependencies: ["HorarissModel"]),
        // Design system: tokens, typography and adaptive colors from an asset
        // catalog, which Skip can read on Android.
        .target(name: "HorarissUI", dependencies: ["HorarissModel"],
                resources: [.process("Resources")]),
        // Layout of the printable weekly PDF: pure arithmetic, so the lane
        // assignment for overlapping classes is computed once for both platforms.
        .target(name: "HorarissPDF", dependencies: ["HorarissModel"]),
        .testTarget(name: "HorarissModelTests", dependencies: ["HorarissModel"]),
        .testTarget(name: "HorarissPDFTests", dependencies: ["HorarissPDF"]),
        .testTarget(name: "HorarissServiciosTests", dependencies: ["HorarissServicios"])
    ]
)
