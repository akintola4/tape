//
//  TapeWidgetViews.swift
//  Tape
//
//  Shared between the app AND the widget extension.
//
//  The widget's views, one per family. They live here rather than in the
//  extension so the tests can render them to the screenshots in the README.
//  The extension wraps them with the tap link and the container background.
//
//  Lock Screen widgets are drawn by the system in one vibrant colour, so they
//  lean on type weight. The Home Screen one gets the baby blue.
//

import SwiftUI
import WidgetKit

struct TapeWidgetView: View {
    let conversion: WidgetConversion
    let family: WidgetFamily

    var body: some View {
        Group {
            switch family {
            case .accessoryInline: TapeInlineWidget(conversion: conversion)
            case .accessoryCircular: TapeCircularWidget(conversion: conversion)
            case .accessoryRectangular: TapeRectangularWidget(conversion: conversion)
            default: TapeSmallWidget(conversion: conversion)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(conversion.spokenText())
    }
}

// MARK: - Home Screen

/// The input on top, the answer big, the next most useful unit underneath.
struct TapeSmallWidget: View {
    let conversion: WidgetConversion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(conversion.inputText())
                .font(Theme.display(.subheadline).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: Tokens.Spacing.sm)
            Text(conversion.answerNumber())
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .widgetAccentable()
            Text(conversion.to.name)
                .font(Theme.display(.subheadline).weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: Tokens.Spacing.sm)
            if let secondary = conversion.secondaryText() {
                Text(secondary)
                    .font(Theme.display(.caption).weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Behind the Home Screen widget: the card colour with a faint wash of the
/// accent from the top, the one depth cue.
struct TapeWidgetBackground: View {
    var body: some View {
        ZStack {
            Theme.cardBackground
            LinearGradient(
                colors: [Theme.accent.opacity(0.14), Theme.accent.opacity(0)],
                startPoint: .top,
                endPoint: .center
            )
        }
    }
}

// MARK: - Lock Screen

/// "1 plot", then "668.9 m²" big, then "Square metres".
struct TapeRectangularWidget: View {
    let conversion: WidgetConversion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(conversion.inputText())
                .font(Theme.display(.headline))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .widgetAccentable()
            Text(conversion.answerText())
                .font(Theme.display(.title2).weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(conversion.to.name)
                .font(Theme.display(.caption).weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "1 plot = 668.9 m²" above the clock, or just "668.9 m²" if that's too long.
struct TapeInlineWidget: View {
    let conversion: WidgetConversion

    var body: some View {
        ViewThatFits {
            Text(conversion.inlineText())
            Text(conversion.answerText())
        }
        .monospacedDigit()
    }
}

/// A small label for the input, then the answer rounded to fit the circle.
struct TapeCircularWidget: View {
    let conversion: WidgetConversion

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                // Narrower than the value: near the top, the circle is too.
                Text(conversion.inputText())
                    .font(Theme.display(.caption2).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: 48)
                Text(conversion.compactNumber())
                    .font(Theme.display(.title3).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .widgetAccentable()
                Text(conversion.answerSymbol)
                    .font(Theme.display(.caption).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .monospacedDigit()
            .padding(.horizontal, Tokens.Spacing.xs + Tokens.Spacing.xxs)
        }
    }
}
