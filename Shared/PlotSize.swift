//
//  PlotSize.swift
//  Tape
//
//  The plot of land, the unit people in Lagos and Abuja actually buy in. There's
//  no single legal size, so it's a setting.
//
//  The usual one is 60 × 120 ft = 7,200 ft² = 668.9 m². Plenty of websites
//  say a plot is 648 m², but that's the metric 18 × 36 m plot, which is a
//  little smaller.
//

import Foundation

nonisolated enum PlotPreset: String, CaseIterable, Identifiable, Sendable {
    /// 60 × 120 ft, the common plot in Lagos and Abuja. The default.
    case feet60x120
    case feet50x100
    /// 18 × 36 m, the metric plot behind the 648 m² figure.
    case metres18x36
    case custom

    var id: String { rawValue }
}

nonisolated enum PlotSideUnit: String, CaseIterable, Identifiable, Sendable {
    case feet, metres

    var id: String { rawValue }
    var symbol: String { self == .feet ? "ft" : "m" }
    var metres: Double { self == .feet ? 0.3048 : 1 }
}

nonisolated struct PlotSize: Equatable, Sendable {
    var preset: PlotPreset = .feet60x120
    /// Only used when `preset` is `.custom`.
    var customWidth: Double = 60
    var customLength: Double = 120
    var customUnit: PlotSideUnit = .feet

    static let standard = PlotSize()

    /// Width, length and the unit they're in, for whichever preset is chosen.
    var sides: (width: Double, length: Double, unit: PlotSideUnit) {
        switch preset {
        case .feet60x120: (60, 120, .feet)
        case .feet50x100: (50, 100, .feet)
        case .metres18x36: (18, 36, .metres)
        case .custom: (customWidth, customLength, customUnit)
        }
    }

    var squareMetres: Double {
        let s = sides
        return s.width * s.unit.metres * s.length * s.unit.metres
    }

    /// A custom plot with a zero or blank side would make every area infinite.
    var isValid: Bool { squareMetres > 0 && squareMetres.isFinite }
}
