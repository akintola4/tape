//
//  TapeApp.swift
//  Tape
//
//  Tape converts one number into every other unit of its category at once.
//  One screen, no network, no account.
//

import SwiftUI

@main
struct TapeApp: App {
    @State private var settings = AppSettings()
    /// Once per cold launch. Coming back from the background skips it.
    @State private var showSplash = !LaunchOptions.skipSplash
    @State private var splashStart: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let splashTimeline = SplashLogic.Timeline(variant: LaunchOptions.splashVariant)
        .slowed(by: LaunchOptions.splashSlowdown)

    var body: some Scene {
        WindowGroup {
            ZStack {
                TimelineView(.animation(paused: !showSplash)) { context in
                    ConverterView(settings: settings)
                        .scaleEffect(appScale(at: context.date))
                }
                if showSplash {
                    SplashOverlay(
                        haptics: settings.haptics,
                        timeline: splashTimeline,
                        onStart: { splashStart = $0 },
                        onFinish: { showSplash = false }
                    )
                }
            }
        }
    }

    private func appScale(at date: Date) -> CGFloat {
        guard showSplash, !reduceMotion else { return 1 }
        let t = splashStart.map { date.timeIntervalSince($0) } ?? 0
        return SplashLogic.appScale(at: t, in: splashTimeline)
    }
}

// MARK: - Launch arguments

/// Debug-only switches for screenshots, set in the scheme or passed to
/// `simctl launch`. Each one only changes what the app opens on; nothing is
/// saved until you change it by hand.
enum LaunchOptions {
    /// `-TapeCategory area`: open on this category.
    static var category: UnitCategory? { value(after: "-TapeCategory").flatMap(UnitCategory.init(rawValue:)) }

    /// `-TapeUnit plot`: the input unit, by id (see `UnitCatalog`).
    static var unitID: String? { value(after: "-TapeUnit") }

    /// `-TapeAmount 2.5`: the amount, as you'd type it.
    static var amount: String? { value(after: "-TapeAmount") }

    /// `-TapeOpenSettings`: open the settings sheet on launch.
    static var openSettings: Bool { flag("-TapeOpenSettings") }

    /// `-TapeDemoToast`: show the "Copied" toast for the first row, and leave it up.
    static var demoToast: Bool { flag("-TapeDemoToast") }

    /// `-TapeNoSplash`: open straight on the converter, for screenshots.
    static var skipSplash: Bool { flag("-TapeNoSplash") }

    /// `-TapeSplashSlow`: play the opening animation 4× slower, for tuning it.
    static var splashSlowdown: Double { flag("-TapeSplashSlow") ? 4 : 1 }

    /// `-TapeSplash pull|wipe|reel`: which opening animation to play while
    /// one is being chosen. Pull when absent.
    static var splashVariant: SplashLogic.Variant {
        value(after: "-TapeSplash").flatMap(SplashLogic.Variant.init(rawValue:)) ?? .pull
    }

    private static func flag(_ name: String) -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(name)
        #else
        false
        #endif
    }

    private static func value(after name: String) -> String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
        #else
        nil
        #endif
    }
}
