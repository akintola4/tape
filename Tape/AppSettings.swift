//
//  AppSettings.swift
//  Tape
//
//  App target ONLY. Reactive wrapper over the App Group's UserDefaults for the
//  settings sheet: plot size, decimals and haptics. Reading and writing go
//  through TapePersistence. The widget shows the plot size and decimals too,
//  so changing either reloads it.
//

import SwiftUI
import WidgetKit

@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var plot: PlotSize { didSet { TapePersistence.save(plot: plot, to: defaults); reloadWidgets() } }
    var decimals: DecimalPreference { didSet { defaults.set(decimals.rawValue, forKey: SettingsKeys.decimals); reloadWidgets() } }
    var haptics: Bool { didSet { defaults.set(haptics, forKey: SettingsKeys.haptics) } }

    init(defaults: UserDefaults = TapeShared.defaults) {
        self.defaults = defaults
        plot = TapePersistence.plot(from: defaults)
        decimals = TapePersistence.decimals(from: defaults)
        haptics = defaults.object(forKey: SettingsKeys.haptics) as? Bool ?? true
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
