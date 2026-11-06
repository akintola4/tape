//
//  UnitCatalog.swift
//  Tape
//
//  Every unit Tape knows, grouped by category, with the Foundation `Dimension`
//  behind each one. Where Foundation's coefficient is rounded (pounds, gallons,
//  fluid ounces) or the unit doesn't exist (the 240 ml cup, the plot), the unit
//  is built here with the exact legal definition instead.
//

import Foundation

nonisolated enum UnitCategory: String, CaseIterable, Identifiable, Sendable {
    case length, area, weight, volume, temperature, cooking

    var id: String { rawValue }

    var title: String {
        switch self {
        case .length: "Length"
        case .area: "Area"
        case .weight: "Weight"
        case .volume: "Volume"
        case .temperature: "Temperature"
        case .cooking: "Cooking"
        }
    }

    /// What a new install shows in this category before anything is typed.
    var defaultUnitID: String {
        switch self {
        case .length: "m"
        case .area: "plot"
        case .weight: "kg"
        case .volume: "l"
        case .temperature: "c"
        case .cooking: "cup"
        }
    }

    var defaultAmount: String {
        switch self {
        case .length: "1.83"
        case .area, .weight, .volume, .cooking: "1"
        case .temperature: "37"
        }
    }

    /// Only temperature goes below zero.
    var allowsNegative: Bool { self == .temperature }

    var units: [TapeUnit] { UnitCatalog.units(in: self) }
}

nonisolated struct TapeUnit: Identifiable, Hashable, Sendable {
    let category: UnitCategory
    /// Unique within its category. Used as the UserDefaults value, so no dots.
    let id: String
    /// "Square metres". Shown in rows and the unit menu.
    let name: String
    /// "m²". Shown after every value.
    let symbol: String
    /// "plots" when it differs from `symbol` for values other than 1.
    var pluralSymbol: String? = nil

    func symbol(for value: Double) -> String {
        guard let pluralSymbol, abs(value) != 1 else { return symbol }
        return pluralSymbol
    }
}

nonisolated enum UnitCatalog {
    static func units(in category: UnitCategory) -> [TapeUnit] {
        switch category {
        case .length:
            [
                TapeUnit(category: .length, id: "mm", name: "Millimetres", symbol: "mm"),
                TapeUnit(category: .length, id: "cm", name: "Centimetres", symbol: "cm"),
                TapeUnit(category: .length, id: "m", name: "Metres", symbol: "m"),
                TapeUnit(category: .length, id: "km", name: "Kilometres", symbol: "km"),
                TapeUnit(category: .length, id: "in", name: "Inches", symbol: "in"),
                TapeUnit(category: .length, id: "ft", name: "Feet", symbol: "ft"),
                TapeUnit(category: .length, id: "yd", name: "Yards", symbol: "yd"),
                TapeUnit(category: .length, id: "mi", name: "Miles", symbol: "mi"),
            ]
        case .area:
            [
                TapeUnit(category: .area, id: "m2", name: "Square metres", symbol: "m²"),
                TapeUnit(category: .area, id: "ft2", name: "Square feet", symbol: "ft²"),
                TapeUnit(category: .area, id: "yd2", name: "Square yards", symbol: "yd²"),
                TapeUnit(category: .area, id: "acre", name: "Acres", symbol: "ac"),
                TapeUnit(category: .area, id: "ha", name: "Hectares", symbol: "ha"),
                TapeUnit(category: .area, id: "plot", name: "Plots", symbol: "plot", pluralSymbol: "plots"),
            ]
        case .weight:
            [
                TapeUnit(category: .weight, id: "g", name: "Grams", symbol: "g"),
                TapeUnit(category: .weight, id: "kg", name: "Kilograms", symbol: "kg"),
                TapeUnit(category: .weight, id: "lb", name: "Pounds", symbol: "lb"),
                TapeUnit(category: .weight, id: "oz", name: "Ounces", symbol: "oz"),
                TapeUnit(category: .weight, id: "st", name: "Stone", symbol: "st"),
                TapeUnit(category: .weight, id: "t", name: "Tonnes", symbol: "t"),
            ]
        case .volume:
            [
                TapeUnit(category: .volume, id: "ml", name: "Millilitres", symbol: "mL"),
                TapeUnit(category: .volume, id: "l", name: "Litres", symbol: "L"),
                TapeUnit(category: .volume, id: "galus", name: "US gallons", symbol: "US gal"),
                TapeUnit(category: .volume, id: "galuk", name: "UK gallons", symbol: "UK gal"),
                TapeUnit(category: .volume, id: "floz", name: "Fluid ounces (US)", symbol: "fl oz"),
                TapeUnit(category: .volume, id: "m3", name: "Cubic metres", symbol: "m³"),
            ]
        case .temperature:
            [
                TapeUnit(category: .temperature, id: "c", name: "Celsius", symbol: "°C"),
                TapeUnit(category: .temperature, id: "f", name: "Fahrenheit", symbol: "°F"),
                TapeUnit(category: .temperature, id: "k", name: "Kelvin", symbol: "K"),
            ]
        case .cooking:
            [
                TapeUnit(category: .cooking, id: "cup", name: "Cups", symbol: "cup", pluralSymbol: "cups"),
                TapeUnit(category: .cooking, id: "tbsp", name: "Tablespoons", symbol: "tbsp"),
                TapeUnit(category: .cooking, id: "tsp", name: "Teaspoons", symbol: "tsp"),
                TapeUnit(category: .cooking, id: "ml", name: "Millilitres", symbol: "mL"),
                TapeUnit(category: .cooking, id: "l", name: "Litres", symbol: "L"),
                TapeUnit(category: .cooking, id: "floz", name: "Fluid ounces (US)", symbol: "fl oz"),
            ]
        }
    }

    static func unit(_ id: String, in category: UnitCategory) -> TapeUnit? {
        units(in: category).first { $0.id == id }
    }

    /// The unit with `id`, or the category's default when `id` is unknown
    /// (an old saved value, or a typo in a launch argument).
    static func unitOrDefault(_ id: String?, in category: UnitCategory) -> TapeUnit {
        id.flatMap { unit($0, in: category) } ?? unit(category.defaultUnitID, in: category)!
    }

    // MARK: Dimensions

    /// The Foundation dimension for a linear unit. Temperature has none: it
    /// converts with offsets, in `UnitsLogic.convertTemperature`.
    static func dimension(for unit: TapeUnit, plot: PlotSize) -> Dimension? {
        switch (unit.category, unit.id) {
        case (.length, "mm"): UnitLength.millimeters
        case (.length, "cm"): UnitLength.centimeters
        case (.length, "m"): UnitLength.meters
        case (.length, "km"): UnitLength.kilometers
        case (.length, "in"): UnitLength.inches
        case (.length, "ft"): UnitLength.feet
        case (.length, "yd"): UnitLength.yards
        case (.length, "mi"): UnitLength.miles

        case (.area, "m2"): UnitArea.squareMeters
        case (.area, "ft2"): UnitArea.squareFeet
        case (.area, "yd2"): UnitArea.squareYards
        case (.area, "acre"): UnitArea.acres
        case (.area, "ha"): UnitArea.hectares
        case (.area, "plot"): UnitArea(symbol: "plot", converter: UnitConverterLinear(coefficient: plot.isValid ? plot.squareMetres : PlotSize.standard.squareMetres))

        case (.weight, "g"): UnitMass.grams
        case (.weight, "kg"): UnitMass.kilograms
        case (.weight, "lb"): ExactUnits.pound
        case (.weight, "oz"): ExactUnits.ounce
        case (.weight, "st"): ExactUnits.stone
        case (.weight, "t"): UnitMass.metricTons

        case (.volume, "ml"), (.cooking, "ml"): UnitVolume.milliliters
        case (.volume, "l"), (.cooking, "l"): UnitVolume.liters
        case (.volume, "galus"): ExactUnits.usGallon
        case (.volume, "galuk"): UnitVolume.imperialGallons
        case (.volume, "floz"), (.cooking, "floz"): ExactUnits.usFluidOunce
        case (.volume, "m3"): UnitVolume.cubicMeters

        case (.cooking, "cup"): ExactUnits.cup
        case (.cooking, "tbsp"): ExactUnits.tablespoon
        case (.cooking, "tsp"): ExactUnits.teaspoon

        default: nil
        }
    }
}

/// Units whose Foundation coefficient is rounded, or which Foundation doesn't
/// have, defined exactly. Base units: kilograms for mass, litres for volume.
nonisolated enum ExactUnits {
    /// The international pound, 0.45359237 kg exactly (Foundation has 0.453592).
    static var pound: UnitMass { UnitMass(symbol: "lb", converter: UnitConverterLinear(coefficient: 0.45359237)) }
    static var ounce: UnitMass { UnitMass(symbol: "oz", converter: UnitConverterLinear(coefficient: 0.45359237 / 16)) }
    static var stone: UnitMass { UnitMass(symbol: "st", converter: UnitConverterLinear(coefficient: 0.45359237 * 14)) }

    /// 231 cubic inches.
    static var usGallon: UnitVolume { UnitVolume(symbol: "US gal", converter: UnitConverterLinear(coefficient: 3.785411784)) }
    /// 1/128 of a US gallon.
    static var usFluidOunce: UnitVolume { UnitVolume(symbol: "fl oz", converter: UnitConverterLinear(coefficient: 3.785411784 / 128)) }

    /// The 240 ml cup on most measuring cups and nutrition labels (the US
    /// "legal cup"). A tablespoon is a sixteenth of it, a teaspoon a third of that.
    static var cup: UnitVolume { UnitVolume(symbol: "cup", converter: UnitConverterLinear(coefficient: 0.240)) }
    static var tablespoon: UnitVolume { UnitVolume(symbol: "tbsp", converter: UnitConverterLinear(coefficient: 0.015)) }
    static var teaspoon: UnitVolume { UnitVolume(symbol: "tsp", converter: UnitConverterLinear(coefficient: 0.005)) }
}
