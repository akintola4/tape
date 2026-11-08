//
//  WidgetScreenshots.swift
//  TapeTests
//
//  Renders the real widget views (Shared/TapeWidgetViews.swift) into the PNGs
//  in docs/screenshots/widgets/, on a stand-in Home Screen and Lock Screen.
//  The Simulator can't add a widget without tapping, so this is how the README
//  gets its pictures. Skipped unless asked for; run scripts/widget-screenshots.sh.
//

import Testing
import SwiftUI
import WidgetKit
@testable import Tape

@MainActor
@Suite("Widget screenshots", .enabled(if: ProcessInfo.processInfo.environment["TAPE_WIDGET_SHOTS"] != nil))
struct WidgetScreenshots {
    /// iPhone 17 Pro sizes, in points.
    private static let small = CGSize(width: 170, height: 170)
    private static let rectangular = CGSize(width: 172, height: 76)
    private static let circular = CGSize(width: 76, height: 76)
    private static let screenWidth: CGFloat = 402

    private static let output = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "docs/screenshots/widgets")

    private static let conversions: [WidgetConversion] = [
        .standard(),
        .resolve(category: .volume, fromID: "galus", toID: "floz", amount: 2.5),
        .resolve(category: .area, fromID: "acre", toID: "yd2", amount: 1),
        .resolve(category: .temperature, fromID: "c", toID: "f", amount: -18),
    ]

    @Test(arguments: [ColorScheme.light, .dark])
    func homeScreen(_ scheme: ColorScheme) throws {
        let grid = Grid(horizontalSpacing: 22, verticalSpacing: 22) {
            GridRow {
                homeWidget(Self.conversions[0])
                homeWidget(Self.conversions[1])
            }
            GridRow {
                homeWidget(Self.conversions[2])
                homeWidget(Self.conversions[3])
            }
        }
        .padding(.vertical, 28)
        .frame(width: Self.screenWidth)
        .background(Wallpaper(scheme: scheme))
        .environment(\.colorScheme, scheme)
        try save(grid, as: "home-\(scheme == .dark ? "dark" : "light").png")
    }

    @Test(arguments: [0, 1])
    func lockScreen(_ index: Int) throws {
        let conversion = Self.conversions[index]
        let screen = VStack(spacing: 6) {
            TapeWidgetView(conversion: conversion, family: .accessoryInline)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .frame(width: 280)
            Text("9:41")
                .font(.system(size: 104, weight: .semibold, design: .rounded))
                .monospacedDigit()
            HStack(spacing: 12) {
                TapeWidgetView(conversion: conversion, family: .accessoryRectangular)
                    .frame(width: Self.rectangular.width, height: Self.rectangular.height)
                lockCircle(conversion)
                lockCircle(Self.conversions[3])
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 32)
        .frame(width: Self.screenWidth)
        .background(Wallpaper(scheme: .dark))
        .environment(\.colorScheme, .dark)
        try save(screen, as: "lock-\(index + 1).png")
    }

    // MARK: Helpers

    private func homeWidget(_ conversion: WidgetConversion) -> some View {
        TapeWidgetView(conversion: conversion, family: .systemSmall)
            .padding(16)
            .frame(width: Self.small.width, height: Self.small.height)
            .background(TapeWidgetBackground())
            .clipShape(.rect(cornerRadius: 24, style: .continuous))
    }

    /// `AccessoryWidgetBackground` only draws on a real Lock Screen, so the
    /// stand-in gets the same translucent disc behind it.
    private func lockCircle(_ conversion: WidgetConversion) -> some View {
        TapeWidgetView(conversion: conversion, family: .accessoryCircular)
            .frame(width: Self.circular.width, height: Self.circular.height)
            .background(.white.opacity(0.16), in: .circle)
    }

    private func save(_ view: some View, as name: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        let image = try #require(renderer.uiImage)
        let data = try #require(image.pngData())
        try FileManager.default.createDirectory(at: Self.output, withIntermediateDirectories: true)
        try data.write(to: Self.output.appending(path: name))
    }
}

/// A plain gradient in Tape's blues, standing in for a wallpaper.
private struct Wallpaper: View {
    let scheme: ColorScheme

    var body: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(red: 0.04, green: 0.11, blue: 0.2), Color(red: 0.09, green: 0.3, blue: 0.47)]
                : [Color(red: 0.62, green: 0.83, blue: 0.97), Color(red: 0.86, green: 0.93, blue: 0.98)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
