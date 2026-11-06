//
//  AppSettings.swift
//  Tape
//
//  Reactive wrapper over UserDefaults for the settings sheet: plot size,
//  decimals and haptics. Reading and writing go through TapePersistence.
//

import SwiftUI

@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var plot: PlotSize { didSet { TapePersistence.save(plot: plot, to: defaults) } }
    var decimals: DecimalPreference { didSet { defaults.set(decimals.rawValue, forKey: SettingsKeys.decimals) } }
    var haptics: Bool { didSet { defaults.set(haptics, forKey: SettingsKeys.haptics) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        plot = TapePersistence.plot(from: defaults)
        decimals = TapePersistence.decimals(from: defaults)
        haptics = defaults.object(forKey: SettingsKeys.haptics) as? Bool ?? true
    }
}
