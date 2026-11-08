//
//  ConversionWidget.swift
//  TapeWidget
//
//  One conversion the user picks, on the Lock Screen or the Home Screen. No
//  network and nothing to refresh: the numbers only change when the
//  conversion or the plot size does, and the app reloads the widget then.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct ConversionEntry: TimelineEntry {
    let date: Date
    let conversion: WidgetConversion
}

struct ConversionProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ConversionEntry {
        ConversionEntry(date: .now, conversion: .standard())
    }

    func snapshot(for configuration: ConversionIntent, in context: Context) async -> ConversionEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: ConversionIntent, in context: Context) async -> Timeline<ConversionEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .never)
    }

    /// The plot size and decimals come from the app's settings in the App Group.
    private func entry(for configuration: ConversionIntent) -> ConversionEntry {
        let defaults = TapeShared.defaults
        let conversion = WidgetConversion.resolve(
            category: configuration.category.unitCategory,
            fromID: configuration.fromUnit?.unitID,
            toID: configuration.toUnit?.unitID,
            amount: configuration.amount,
            plot: TapePersistence.plot(from: defaults),
            decimals: TapePersistence.decimals(from: defaults)
        )
        return ConversionEntry(date: .now, conversion: conversion)
    }
}

// MARK: - Widget

struct ConversionWidget: Widget {
    let kind = "TapeConversion"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConversionIntent.self, provider: ConversionProvider()) { entry in
            ConversionWidgetEntryView(entry: entry)
                .widgetURL(entry.conversion.link.url)
                .containerBackground(for: .widget) { TapeWidgetBackground() }
        }
        .configurationDisplayName("Conversion")
        .description("One conversion you pick, like a plot in square metres. Works offline.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct ConversionWidgetEntryView: View {
    let entry: ConversionEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        TapeWidgetView(conversion: entry.conversion, family: family)
    }
}

// MARK: - Previews

private let previewEntries = [
    ConversionEntry(date: .now, conversion: .standard()),
    ConversionEntry(date: .now, conversion: .resolve(category: .volume, fromID: "galus", toID: "floz", amount: 2.5)),
    ConversionEntry(date: .now, conversion: .resolve(category: .temperature, fromID: "c", toID: "f", amount: -18)),
]

#Preview("Small", as: .systemSmall) {
    ConversionWidget()
} timeline: {
    previewEntries[0]
    previewEntries[1]
    previewEntries[2]
}

#Preview("Rectangular", as: .accessoryRectangular) {
    ConversionWidget()
} timeline: {
    previewEntries[0]
    previewEntries[1]
}

#Preview("Inline", as: .accessoryInline) {
    ConversionWidget()
} timeline: {
    previewEntries[0]
}

#Preview("Circular", as: .accessoryCircular) {
    ConversionWidget()
} timeline: {
    previewEntries[0]
    previewEntries[2]
}
