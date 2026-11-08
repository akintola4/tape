//
//  UnitsLogicTests.swift
//  TapeTests
//
//  The pure logic in Shared/: conversions in every category, temperature
//  offsets, plot sizes, rounding and formatting, feet and inches, and typed
//  input. Locales are pinned so these pass on any phone or Mac.
//

import Testing
import Foundation
@testable import Tape

private let gb = Locale(identifier: "en_GB")
private let fr = Locale(identifier: "fr_FR")

private func unit(_ id: String, _ category: UnitCategory) -> TapeUnit {
    UnitCatalog.unit(id, in: category)!
}

private func convert(_ value: Double, _ from: String, _ to: String, _ category: UnitCategory, plot: PlotSize = .standard) -> Double {
    UnitsLogic.convert(value, from: unit(from, category), to: unit(to, category), plot: plot)
}

private func close(_ a: Double, _ b: Double, within tolerance: Double = 1e-9) -> Bool {
    abs(a - b) <= tolerance * max(1, abs(b))
}

// MARK: - Catalog

@Suite("Unit catalog")
struct CatalogTests {
    @Test(arguments: UnitCategory.allCases)
    func everyUnitHasADimensionOrAFormula(_ category: UnitCategory) {
        for item in category.units where category != .temperature {
            #expect(UnitCatalog.dimension(for: item, plot: .standard) != nil, "\(item.id) has no dimension")
        }
    }

    @Test(arguments: UnitCategory.allCases)
    func idsAreUniqueAndHaveNoDots(_ category: UnitCategory) {
        let ids = category.units.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy { !$0.contains(".") })
    }

    @Test(arguments: UnitCategory.allCases)
    func defaultUnitExists(_ category: UnitCategory) {
        #expect(UnitCatalog.unit(category.defaultUnitID, in: category) != nil)
        #expect(UnitsLogic.parseAmount(category.defaultAmount, locale: gb) != nil)
    }

    @Test func categoriesHaveTheUnitsTheBriefAsksFor() {
        #expect(UnitCategory.length.units.map(\.id) == ["mm", "cm", "m", "km", "in", "ft", "yd", "mi"])
        #expect(UnitCategory.area.units.map(\.id) == ["m2", "ft2", "yd2", "acre", "ha", "plot"])
        #expect(UnitCategory.weight.units.map(\.id) == ["g", "kg", "lb", "oz", "st", "t"])
        #expect(UnitCategory.volume.units.map(\.id) == ["ml", "l", "galus", "galuk", "floz", "m3"])
        #expect(UnitCategory.temperature.units.map(\.id) == ["c", "f", "k"])
        #expect(UnitCategory.cooking.units.map(\.id) == ["cup", "tbsp", "tsp", "ml", "l", "floz"])
    }

    @Test func unknownIDFallsBackToTheDefault() {
        #expect(UnitCatalog.unitOrDefault("furlong", in: .length).id == "m")
        #expect(UnitCatalog.unitOrDefault(nil, in: .area).id == "plot")
    }

    @Test func pluralSymbols() {
        #expect(unit("plot", .area).symbol(for: 1) == "plot")
        #expect(unit("plot", .area).symbol(for: 2.5) == "plots")
        #expect(unit("cup", .cooking).symbol(for: 0.5) == "cups")
        #expect(unit("m2", .area).symbol(for: 2) == "m²")
    }
}

// MARK: - Conversions

@Suite("Conversions")
struct ConversionTests {
    @Test func lengthUsesExactDefinitions() {
        #expect(close(convert(1, "ft", "m", .length), 0.3048))
        #expect(close(convert(1, "in", "cm", .length), 2.54))
        #expect(close(convert(1, "mi", "km", .length), 1.609344))
        #expect(close(convert(1, "yd", "ft", .length), 3))
        #expect(close(convert(1, "km", "mm", .length), 1_000_000))
    }

    @Test func areaUsesExactDefinitions() {
        #expect(close(convert(1, "ft2", "m2", .area), 0.09290304))
        #expect(close(convert(1, "acre", "m2", .area), 4046.8564224))
        #expect(close(convert(1, "ha", "m2", .area), 10_000))
        #expect(close(convert(1, "yd2", "ft2", .area), 9))
        #expect(close(convert(1, "acre", "ft2", .area), 43_560))
    }

    @Test func weightUsesTheInternationalPound() {
        #expect(close(convert(1, "lb", "kg", .weight), 0.45359237))
        #expect(close(convert(1, "lb", "oz", .weight), 16))
        #expect(close(convert(1, "st", "lb", .weight), 14))
        #expect(close(convert(1, "t", "kg", .weight), 1000))
        #expect(close(convert(1, "kg", "g", .weight), 1000))
    }

    @Test func volumeUsesUSAndImperialGallons() {
        #expect(close(convert(1, "galus", "l", .volume), 3.785411784))
        #expect(close(convert(1, "galuk", "l", .volume), 4.54609))
        #expect(close(convert(1, "galus", "floz", .volume), 128))
        #expect(close(convert(1, "m3", "l", .volume), 1000))
        #expect(close(convert(1, "l", "ml", .volume), 1000))
    }

    @Test func cookingUsesThe240mlCup() {
        #expect(close(convert(1, "cup", "ml", .cooking), 240))
        #expect(close(convert(1, "cup", "tbsp", .cooking), 16))
        #expect(close(convert(1, "tbsp", "tsp", .cooking), 3))
        #expect(close(convert(1, "floz", "ml", .cooking), 29.5735295625))
        #expect(close(convert(1, "l", "cup", .cooking), 1000.0 / 240))
    }

    @Test(arguments: UnitCategory.allCases)
    func everyPairRoundTrips(_ category: UnitCategory) {
        let value = 123.456
        for from in category.units {
            for to in category.units {
                let there = UnitsLogic.convert(value, from: from, to: to)
                let back = UnitsLogic.convert(there, from: to, to: from)
                #expect(close(back, value), "\(from.id) → \(to.id) → \(from.id) gave \(back)")
            }
        }
    }

    @Test func sameUnitIsUnchanged() {
        #expect(convert(42, "kg", "kg", .weight) == 42)
    }
}

// MARK: - Temperature

@Suite("Temperature uses offsets, not ratios")
struct TemperatureTests {
    @Test(arguments: [
        (0.0, 32.0), (100, 212), (37, 98.6), (-40, -40), (-17.7777777778, 0),
    ])
    func celsiusToFahrenheit(_ celsius: Double, _ fahrenheit: Double) {
        #expect(close(convert(celsius, "c", "f", .temperature), fahrenheit, within: 1e-6))
    }

    @Test func kelvin() {
        #expect(close(convert(0, "c", "k", .temperature), 273.15))
        #expect(close(convert(0, "k", "c", .temperature), -273.15))
        #expect(close(convert(32, "f", "k", .temperature), 273.15))
        #expect(close(convert(212, "f", "k", .temperature), 373.15))
    }

    @Test func doublingCelsiusDoesNotDoubleFahrenheit() {
        // A ratio would make 20 °C twice as many °F as 10 °C. An offset doesn't.
        #expect(convert(20, "c", "f", .temperature) != 2 * convert(10, "c", "f", .temperature))
    }

    @Test func temperatureShowsAtMostTwoDecimals() {
        let fahrenheit = unit("f", .temperature)
        let kelvin = unit("k", .temperature)
        #expect(UnitsLogic.format(convert(37, "c", "f", .temperature), unit: fahrenheit, locale: gb) == "98.6 °F")
        #expect(UnitsLogic.format(convert(0, "c", "k", .temperature), unit: kelvin, locale: gb) == "273.15 K")
        #expect(UnitsLogic.format(convert(100, "c", "f", .temperature), unit: fahrenheit, locale: gb) == "212 °F")
        #expect(UnitsLogic.format(-40, unit: fahrenheit, locale: gb) == "−40 °F")
    }
}

// MARK: - Minus sign

@Suite("Negative numbers use the true minus")
struct MinusSignTests {
    private let minus: Character = "\u{2212}"

    @Test func fahrenheitBelowZero() {
        // 0 °F is −17.78 °C, and −18 °C is −0.4 °F.
        let shown = UnitsLogic.format(convert(-18, "c", "f", .temperature), unit: unit("f", .temperature), locale: gb)
        #expect(shown == "−0.4 °F")
        #expect(shown.first == minus)
        #expect(!shown.contains("-"))
    }

    @Test func celsiusBelowZero() {
        #expect(UnitsLogic.format(-18, unit: unit("c", .temperature), locale: gb) == "−18 °C")
    }

    @Test func minusFortyIsTheSameInBothScales() {
        let fahrenheit = convert(-40, "c", "f", .temperature)
        #expect(UnitsLogic.format(fahrenheit, unit: unit("f", .temperature), locale: gb) == "−40 °F")
        let rows = UnitsLogic.rows(for: -40, from: unit("c", .temperature), locale: gb)
        #expect(rows.first?.copyText == "−40 °F")
        #expect(rows.allSatisfy { !$0.value.contains("-") })
    }

    @Test func otherLocalesGetItToo() {
        #expect(UnitsLogic.formatNumber(-18.5, unit: unit("c", .temperature), locale: fr) == "−18,5")
    }

    @Test func negativeZeroIsJustZero() {
        #expect(UnitsLogic.formatNumber(-0.0001, unit: unit("c", .temperature), locale: gb) == "0")
    }

    @Test func feetAndInchesBelowZero() {
        #expect(UnitsLogic.formatFeetAndInches(metres: -1.8288, locale: gb) == "−6′ 0″")
    }

    @Test func typingAHyphenShowsTheTrueMinus() {
        #expect(UnitsLogic.sanitizeAmount("-18", allowsNegative: true, locale: gb) == "−18")
        #expect(UnitsLogic.parseAmount("−18", locale: gb) == -18)
        #expect(UnitsLogic.parseAmount("-18", locale: gb) == -18)
    }
}

// MARK: - Plots

@Suite("Plot of land")
struct PlotTests {
    @Test func defaultPlotIs60By120Feet() {
        #expect(PlotSize.standard.preset == .feet60x120)
        #expect(abs(PlotSize.standard.squareMetres - 668.9) < 0.05)
        #expect(close(PlotSize.standard.squareMetres, 668.901888))
    }

    @Test func onePlotInEveryAreaUnit() {
        #expect(abs(convert(1, "plot", "m2", .area) - 668.9) < 0.05)
        #expect(close(convert(1, "plot", "ft2", .area), 7200))
        #expect(close(convert(1, "plot", "yd2", .area), 800))
        #expect(close(convert(1, "plot", "acre", .area), 7200.0 / 43_560))
        #expect(close(convert(1, "plot", "ha", .area), 0.0668901888))
    }

    @Test func aboutSixPlotsToAnAcre() {
        let plots = convert(1, "acre", "plot", .area)
        #expect(close(plots, 6.05, within: 0.001))
        #expect(UnitsLogic.format(plots, unit: unit("plot", .area), locale: gb) == "6.05 plots")
    }

    @Test func metricPlotIs648SquareMetres() {
        var plot = PlotSize()
        plot.preset = .metres18x36
        #expect(close(plot.squareMetres, 648))
        #expect(close(convert(1, "plot", "m2", .area, plot: plot), 648))
    }

    @Test func fiftyByHundredFeet() {
        var plot = PlotSize()
        plot.preset = .feet50x100
        #expect(close(plot.squareMetres, 464.5152))
    }

    @Test func customPlotInFeetAndMetres() {
        var plot = PlotSize(preset: .custom, customWidth: 30, customLength: 40, customUnit: .metres)
        #expect(close(plot.squareMetres, 1200))
        plot.customUnit = .feet
        #expect(close(plot.squareMetres, 1200 * 0.09290304))
    }

    @Test func zeroSizedCustomPlotFallsBackToTheStandardOne() {
        let plot = PlotSize(preset: .custom, customWidth: 0, customLength: 120, customUnit: .feet)
        #expect(!plot.isValid)
        #expect(abs(convert(1, "plot", "m2", .area, plot: plot) - 668.9) < 0.05)
    }

    @Test func the648FigureIsNot60By120Feet() {
        // The mistake this app exists to avoid.
        #expect(abs(PlotSize.standard.squareMetres - 648) > 20)
    }

    @Test func summaries() {
        #expect(UnitsLogic.plotDimensions(.standard, locale: gb) == "60 × 120 ft")
        #expect(UnitsLogic.plotSummary(.standard, locale: gb) == "60 × 120 ft · 668.9 m²")
        var metric = PlotSize()
        metric.preset = .metres18x36
        #expect(UnitsLogic.plotSummary(metric, locale: gb) == "18 × 36 m · 648 m²")
        let custom = PlotSize(preset: .custom, customWidth: 15.5, customLength: 30, customUnit: .metres)
        #expect(UnitsLogic.plotDimensions(custom, locale: fr) == "15,5 × 30 m")
    }
}

// MARK: - Rounding and formatting

@Suite("Rounding and formatting")
struct FormattingTests {
    private let squareMetres = unit("m2", .area)
    private let acres = unit("acre", .area)

    @Test func autoKeepsFourSignificantFigures() {
        #expect(UnitsLogic.formatNumber(668.901888, unit: squareMetres, locale: gb) == "668.9")
        #expect(UnitsLogic.formatNumber(0.165289256, unit: acres, locale: gb) == "0.1653")
        #expect(UnitsLogic.formatNumber(0.0668901888, unit: squareMetres, locale: gb) == "0.06689")
        #expect(UnitsLogic.formatNumber(6.689, unit: squareMetres, locale: gb) == "6.689")
    }

    @Test func autoNeverRoundsAwayWholeDigits() {
        #expect(UnitsLogic.formatNumber(7200, unit: squareMetres, locale: gb) == "7,200")
        #expect(UnitsLogic.formatNumber(1_234_567.89, unit: squareMetres, locale: gb) == "1,234,568")
    }

    @Test func noFloatNoise() {
        #expect(UnitsLogic.formatNumber(0.1 + 0.2, unit: squareMetres, locale: gb) == "0.3")
        #expect(UnitsLogic.formatNumber(convert(100, "c", "f", .temperature), unit: unit("f", .temperature), locale: gb) == "212")
        #expect(UnitsLogic.formatNumber(convert(3, "ft", "yd", .length), unit: unit("yd", .length), locale: gb) == "1")
    }

    @Test func trailingZerosGoInAuto() {
        #expect(UnitsLogic.formatNumber(2.5, unit: squareMetres, locale: gb) == "2.5")
        #expect(UnitsLogic.formatNumber(16, unit: unit("tbsp", .cooking), locale: gb) == "16")
    }

    @Test func zeroAndNegativeZero() {
        #expect(UnitsLogic.formatNumber(0, unit: squareMetres, locale: gb) == "0")
        #expect(UnitsLogic.formatNumber(-0.00000000001, unit: squareMetres, preference: .two, locale: gb) == "0.00")
    }

    @Test func fixedPreferencesAreExact() {
        #expect(UnitsLogic.formatNumber(668.901888, unit: squareMetres, preference: .zero, locale: gb) == "669")
        #expect(UnitsLogic.formatNumber(668.901888, unit: squareMetres, preference: .two, locale: gb) == "668.90")
        #expect(UnitsLogic.formatNumber(0.165289256, unit: acres, preference: .four, locale: gb) == "0.1653")
        #expect(UnitsLogic.formatNumber(7200, unit: squareMetres, preference: .two, locale: gb) == "7,200.00")
    }

    @Test func roundsHalfUp() {
        #expect(UnitsLogic.formatNumber(2.5, unit: squareMetres, preference: .zero, locale: gb) == "3")
        #expect(UnitsLogic.formatNumber(1.005, unit: squareMetres, preference: .two, locale: gb) == "1.01")
    }

    @Test func localeDecidesTheMarks() {
        #expect(UnitsLogic.formatNumber(668.901888, unit: squareMetres, locale: fr) == "668,9")
        #expect(UnitsLogic.formatNumber(7200, unit: squareMetres, locale: fr) == "7\u{202F}200")
        #expect(UnitsLogic.formatNumber(7200, unit: squareMetres, locale: Locale(identifier: "de_DE")) == "7.200")
    }

    @Test func formatAddsTheSymbol() {
        #expect(UnitsLogic.format(668.901888, unit: squareMetres, locale: gb) == "668.9 m²")
        #expect(UnitsLogic.format(1, unit: unit("plot", .area), locale: gb) == "1 plot")
    }
}

// MARK: - Feet and inches

@Suite("Feet and inches")
struct FeetAndInchesTests {
    @Test func sixFeet() {
        #expect(UnitsLogic.formatFeetAndInches(metres: 1.8288, locale: gb) == "6′ 0″")
    }

    @Test func carriesTwelveInchesIntoAFoot() {
        // 1.83 m is 72.05 in, which rounds to 72.0 in: 6′ 0″, never 5′ 12″.
        #expect(UnitsLogic.formatFeetAndInches(metres: 1.83, locale: gb) == "6′ 0″")
        #expect(UnitsLogic.formatFeetAndInches(metres: 71.98 * 0.0254, locale: gb) == "6′ 0″")
    }

    @Test func tenthsOfAnInch() {
        #expect(UnitsLogic.formatFeetAndInches(metres: 1.76, locale: gb) == "5′ 9.3″")
        #expect(UnitsLogic.formatFeetAndInches(metres: 0.01, locale: gb) == "0′ 0.4″")
    }

    @Test func split() {
        let parts = UnitsLogic.feetAndInches(metres: 1.76)
        #expect(parts.feet == 5)
        #expect(parts.inches == Decimal(string: "9.3"))
        #expect(!parts.negative)
    }

    @Test func usesTheLocalesDecimalMark() {
        #expect(UnitsLogic.formatFeetAndInches(metres: 1.76, locale: fr) == "5′ 9,3″")
    }

    @Test func leadsLengthResultsWhenTypingMetres() {
        let rows = UnitsLogic.rows(for: 1.83, from: unit("m", .length), locale: gb)
        let ids = rows.map(\.id)
        #expect(ids == [UnitsLogic.feetAndInchesID, "ft", "cm", "yd", "in", "mm", "km", "mi"])
        #expect(rows.first { $0.id == UnitsLogic.feetAndInchesID }?.copyText == "6′ 0″")
    }

    @Test func appearsAfterInchesWhenTypingFeet() {
        let ids = UnitsLogic.rows(for: 6, from: unit("ft", .length), locale: gb).map(\.id)
        #expect(ids == ["cm", "m", "in", UnitsLogic.feetAndInchesID, "yd", "mm", "km", "mi"])
    }
}

// MARK: - Result rows

@Suite("Result rows")
struct ResultRowTests {
    @Test func onePlotListsEveryOtherAreaUnit() {
        let rows = UnitsLogic.rows(for: 1, from: unit("plot", .area), locale: gb)
        #expect(rows.map(\.copyText) == ["668.9 m²", "7,200 ft²", "0.1653 ac", "0.06689 ha", "800 yd²"])
    }

    @Test func plotRowFollowsTheSetting() {
        var plot = PlotSize()
        plot.preset = .metres18x36
        let rows = UnitsLogic.rows(for: 1296, from: unit("m2", .area), plot: plot, locale: gb)
        #expect(rows.first?.copyText == "2 plots")
    }

    @Test func inputUnitIsLeftOut() {
        let rows = UnitsLogic.rows(for: 1, from: unit("kg", .weight), locale: gb)
        #expect(!rows.map(\.id).contains("kg"))
        #expect(rows.map(\.copyText) == ["2.205 lb", "0.1575 st", "1,000 g", "35.27 oz", "0.001 t"])
    }

    @Test func cookingRows() {
        let rows = UnitsLogic.rows(for: 1, from: unit("cup", .cooking), locale: gb)
        #expect(rows.map(\.copyText) == ["240 mL", "16 tbsp", "48 tsp", "8.115 fl oz", "0.24 L"])
    }
}

// MARK: - Typed input

@Suite("Typed amounts")
struct AmountInputTests {
    @Test func parsesPlainAndDecimal() {
        #expect(UnitsLogic.parseAmount("100", locale: gb) == 100)
        #expect(UnitsLogic.parseAmount("12.5", locale: gb) == 12.5)
        #expect(UnitsLogic.parseAmount("1,250.75", locale: gb) == 1250.75)
    }

    @Test func usesTheLocalesDecimalMark() {
        #expect(UnitsLogic.parseAmount("12,5", locale: fr) == 12.5)
    }

    @Test func parsesNegatives() {
        #expect(UnitsLogic.parseAmount("-40", locale: gb) == -40)
        #expect(UnitsLogic.parseAmount("−3.5", locale: gb) == -3.5)
    }

    @Test func rejectsEmptyAndJunk() {
        #expect(UnitsLogic.parseAmount("", locale: gb) == nil)
        #expect(UnitsLogic.parseAmount(".", locale: gb) == nil)
        #expect(UnitsLogic.parseAmount("-", locale: gb) == nil)
        #expect(UnitsLogic.parseAmount("1.2.3", locale: gb) == nil)
        #expect(UnitsLogic.parseAmount("abc", locale: gb) == nil)
    }

    @Test func sanitizeKeepsOneMarkAndCapsDecimals() {
        #expect(UnitsLogic.sanitizeAmount("12.3456789", locale: gb) == "12.345678")
        #expect(UnitsLogic.sanitizeAmount("1.2.3", locale: gb) == "1.23")
        #expect(UnitsLogic.sanitizeAmount(".5", locale: gb) == "0.5")
        #expect(UnitsLogic.sanitizeAmount("007", locale: gb) == "7")
        #expect(UnitsLogic.sanitizeAmount("12,5", locale: fr) == "12,5")
    }

    @Test func sanitizeOnlyKeepsAMinusWhereAllowed() {
        #expect(UnitsLogic.sanitizeAmount("-40", allowsNegative: true, locale: gb) == "−40")
        #expect(UnitsLogic.sanitizeAmount("−40", allowsNegative: true, locale: gb) == "−40")
        #expect(UnitsLogic.sanitizeAmount("-40", allowsNegative: false, locale: gb) == "40")
        #expect(UnitsLogic.sanitizeAmount("4-0", allowsNegative: true, locale: gb) == "40")
    }

    @Test func sanitizeCapsWholeDigits() {
        #expect(UnitsLogic.sanitizeAmount("12345678901234", locale: gb) == "123456789012")
    }

    @Test func toggleSign() {
        #expect(UnitsLogic.toggleSign("40") == "−40")
        #expect(UnitsLogic.toggleSign("−40") == "40")
        #expect(UnitsLogic.toggleSign("-40") == "40")
        #expect(UnitsLogic.toggleSign("") == "−")
    }
}

// MARK: - Persistence

@Suite("Remembering the last category, unit and amount")
struct PersistenceTests {
    private let defaults: UserDefaults

    init() {
        let suite = "tape-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func firstLaunchOpensOnOnePlot() {
        #expect(TapePersistence.category(from: defaults) == .area)
        #expect(TapePersistence.unit(for: .area, from: defaults).id == "plot")
        #expect(TapePersistence.amount(for: .area, from: defaults) == "1")
    }

    @Test func remembersEachCategorySeparately() {
        TapePersistence.save(category: .weight, to: defaults)
        TapePersistence.save(unit: unit("lb", .weight), to: defaults)
        TapePersistence.save(amount: "150", for: .weight, to: defaults)
        TapePersistence.save(unit: unit("ft2", .area), to: defaults)

        #expect(TapePersistence.category(from: defaults) == .weight)
        #expect(TapePersistence.unit(for: .weight, from: defaults).id == "lb")
        #expect(TapePersistence.amount(for: .weight, from: defaults) == "150")
        #expect(TapePersistence.unit(for: .area, from: defaults).id == "ft2")
        #expect(TapePersistence.amount(for: .area, from: defaults) == "1")
    }

    @Test func keysAreHyphenated() {
        #expect(SettingsKeys.unit(.area) == "unit-area")
        #expect(SettingsKeys.amount(.cooking) == "amount-cooking")
    }

    @Test func plotRoundTrips() {
        let plot = PlotSize(preset: .custom, customWidth: 15, customLength: 30, customUnit: .metres)
        TapePersistence.save(plot: plot, to: defaults)
        #expect(TapePersistence.plot(from: defaults) == plot)
    }

    @Test func badSavedValuesFallBack() {
        defaults.set("furlongs", forKey: SettingsKeys.category)
        defaults.set("cubit", forKey: SettingsKeys.unit(.length))
        defaults.set("seven", forKey: SettingsKeys.decimals)
        #expect(TapePersistence.category(from: defaults) == .area)
        #expect(TapePersistence.unit(for: .length, from: defaults).id == "m")
        #expect(TapePersistence.decimals(from: defaults) == .auto)
    }
}
