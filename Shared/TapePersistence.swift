//
//  TapePersistence.swift
//  Tape
//
//  Everything Tape remembers, in UserDefaults: settings, the last category,
//  and the unit and amount last used in each category. Every function takes
//  the defaults it reads, so the tests can use a throwaway suite.
//

import Foundation

nonisolated enum SettingsKeys {
    static let category = "category"
    static let decimals = "decimals"
    static let haptics = "haptics"
    static let plotPreset = "plotPreset"
    static let plotWidth = "plotWidth"
    static let plotLength = "plotLength"
    static let plotUnit = "plotUnit"

    /// "unit-area". Hyphenated, never dotted.
    static func unit(_ category: UnitCategory) -> String { "unit-\(category.rawValue)" }
    static func amount(_ category: UnitCategory) -> String { "amount-\(category.rawValue)" }
}

nonisolated enum TapePersistence {
    /// A plot of land is the unit Tape was made for, so it opens on Area.
    static let defaultCategory: UnitCategory = .area

    static func category(from defaults: UserDefaults) -> UnitCategory {
        UnitCategory(rawValue: defaults.string(forKey: SettingsKeys.category) ?? "") ?? defaultCategory
    }

    static func unit(for category: UnitCategory, from defaults: UserDefaults) -> TapeUnit {
        UnitCatalog.unitOrDefault(defaults.string(forKey: SettingsKeys.unit(category)), in: category)
    }

    static func amount(for category: UnitCategory, from defaults: UserDefaults) -> String {
        defaults.string(forKey: SettingsKeys.amount(category)) ?? category.defaultAmount
    }

    static func save(category: UnitCategory, to defaults: UserDefaults) {
        defaults.set(category.rawValue, forKey: SettingsKeys.category)
    }

    static func save(unit: TapeUnit, to defaults: UserDefaults) {
        defaults.set(unit.id, forKey: SettingsKeys.unit(unit.category))
    }

    static func save(amount: String, for category: UnitCategory, to defaults: UserDefaults) {
        defaults.set(amount, forKey: SettingsKeys.amount(category))
    }

    static func decimals(from defaults: UserDefaults) -> DecimalPreference {
        DecimalPreference(rawValue: defaults.string(forKey: SettingsKeys.decimals) ?? "") ?? .auto
    }

    static func plot(from defaults: UserDefaults) -> PlotSize {
        var plot = PlotSize()
        plot.preset = PlotPreset(rawValue: defaults.string(forKey: SettingsKeys.plotPreset) ?? "") ?? .feet60x120
        if let width = defaults.object(forKey: SettingsKeys.plotWidth) as? Double { plot.customWidth = width }
        if let length = defaults.object(forKey: SettingsKeys.plotLength) as? Double { plot.customLength = length }
        plot.customUnit = PlotSideUnit(rawValue: defaults.string(forKey: SettingsKeys.plotUnit) ?? "") ?? .feet
        return plot
    }

    static func save(plot: PlotSize, to defaults: UserDefaults) {
        defaults.set(plot.preset.rawValue, forKey: SettingsKeys.plotPreset)
        defaults.set(plot.customWidth, forKey: SettingsKeys.plotWidth)
        defaults.set(plot.customLength, forKey: SettingsKeys.plotLength)
        defaults.set(plot.customUnit.rawValue, forKey: SettingsKeys.plotUnit)
    }
}
