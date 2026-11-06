//
//  Theme.swift
//  Tape
//
//  Spacing, radii and type scales come from `Tokens` (swiftui-registry). This
//  file holds what is Tape's own: the baby blue and the rounded face for
//  headlines and numbers.
//

import SwiftUI

nonisolated enum Theme {
    /// Baby blue #8FD3FF in dark mode. In light mode the asset catalog's
    /// AccentColor is a deeper #1874B0, because #8FD3FF on white is 1.6:1 and
    /// unreadable as text; #1874B0 is 5.0:1 on white and 4.5:1 on the cards.
    static let accent = Color.accentColor

    /// The active category chip: #8FD3FF in both modes, with `chipText` on it
    /// (9.1:1).
    static let chipFill = Color("ChipFill")
    static let chipText = Color("ChipText")

    /// The screen behind the cards, and the cards. Grouped, so cards are white
    /// on light grey in light mode and grey on black in dark.
    static let screenBackground = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)

    /// SF Rounded, for headlines and every number on screen.
    static func display(_ style: Font.TextStyle) -> Font { .system(style, design: .rounded) }

    /// SF Rounded at a fixed size, for the big amount. Callers pass a
    /// `@ScaledMetric` so it still follows Dynamic Type.
    static func amount(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
    }
}
