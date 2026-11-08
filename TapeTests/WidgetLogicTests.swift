//
//  WidgetLogicTests.swift
//  TapeTests
//
//  What each widget size says, the default conversion, how mismatched widget
//  settings resolve, the tape:// link a tap opens, and the move of settings
//  into the App Group the widget reads.
//

import Testing
import Foundation
@testable import Tape

private let gb = Locale(identifier: "en_GB")
private let fr = Locale(identifier: "fr_FR")

private func conversion(_ category: UnitCategory, _ from: String, _ amount: Double, _ to: String,
                        plot: PlotSize = .standard) -> WidgetConversion {
    WidgetConversion.resolve(category: category, fromID: from, toID: to, amount: amount, plot: plot)
}

@Suite("Widget text")
struct WidgetTextTests {
    @Test func defaultIsOnePlotInSquareMetres() {
        let standard = WidgetConversion.standard()
        #expect(standard.from.id == "plot")
        #expect(standard.to.id == "m2")
        #expect(standard.amount == 1)
        #expect(standard.inputText(locale: gb) == "1 plot")
        #expect(standard.answerText(locale: gb) == "668.9 m²")
    }

    @Test func eachFamilysText() {
        let standard = WidgetConversion.standard()
        // Inline
        #expect(standard.inlineText(locale: gb) == "1 plot = 668.9 m²")
        // Circular
        #expect(standard.compactNumber(locale: gb) == "669")
        #expect(standard.answerSymbol == "m²")
        // Home Screen: the line under the answer
        #expect(standard.secondaryText(locale: gb) == "7,200 ft²")
        #expect(standard.spokenText(locale: gb) == "1 plot is 668.9 square metres")
    }

    @Test func followsThePlotSetting() {
        let metric = PlotSize(preset: .metres18x36)
        let widget = WidgetConversion.standard(plot: metric)
        #expect(widget.answerText(locale: gb) == "648 m²")
        #expect(widget.inlineText(locale: gb) == "1 plot = 648 m²")
    }

    @Test func followsTheDecimalsSetting() {
        let widget = WidgetConversion.standard(decimals: .two)
        #expect(widget.answerText(locale: gb) == "668.90 m²")
    }

    @Test func pluralsAndLongUnits() {
        let gallons = conversion(.volume, "galus", 2.5, "floz")
        #expect(gallons.inlineText(locale: gb) == "2.5 US gal = 320 fl oz")
        #expect(gallons.to.name == "Fluid ounces (US)")
        let yards = conversion(.area, "plot", 2, "yd2")
        #expect(yards.inputText(locale: gb) == "2 plots")
        #expect(yards.answerText(locale: gb) == "1,600 yd²")
    }

    @Test func temperatureBelowZeroUsesTheTrueMinus() {
        let cold = conversion(.temperature, "c", -18, "f")
        #expect(cold.inlineText(locale: gb) == "−18 °C = −0.4 °F")
        #expect(cold.compactNumber(locale: gb) == "−0.4")
    }

    @Test(arguments: [
        (668.9, "669"), (66.89, "66.9"), (6.689, "6.69"), (0.1653, "0.165"),
        (7200, "7,200"), (12_345, "12.3K"), (4_046_856, "4.05M"), (0, "0"), (-40, "−40"),
    ])
    func compactNumbers(_ value: Double, _ expected: String) {
        #expect(WidgetConversion.compact(value, locale: gb) == expected)
    }

    @Test func compactUsesTheLocalesDecimalMark() {
        #expect(WidgetConversion.compact(66.89, locale: fr) == "66,9")
    }
}

@Suite("Widget settings")
struct WidgetResolveTests {
    @Test func unitsFromAnotherCategoryFallBack() {
        // The user picked plot → m², then switched the category to Weight.
        let widget = WidgetConversion.resolve(category: .weight, fromID: "plot", toID: "m2", amount: 1)
        #expect(widget.from.id == "kg")
        #expect(widget.to.id == "lb")
    }

    @Test func nothingPickedUsesTheCategorysUsualUnits() {
        let widget = WidgetConversion.resolve(category: nil, fromID: nil, toID: nil, amount: nil)
        #expect(widget == WidgetConversion.standard())
        #expect(WidgetConversion.resolve(category: .temperature, fromID: nil, toID: nil, amount: 37).to.id == "f")
    }

    @Test func answerUnitIsNeverTheInputUnit() {
        let widget = WidgetConversion.resolve(category: .area, fromID: "m2", toID: "m2", amount: 1)
        #expect(widget.to.id == "plot")
    }

    @Test func lengthSkipsTheFeetAndInchesRow() {
        let widget = WidgetConversion.resolve(category: .length, fromID: "m", toID: nil, amount: 1.83)
        #expect(widget.to.id == "ft")
    }

    @Test func onlyTemperatureKeepsANegativeAmount() {
        #expect(WidgetConversion.resolve(category: .weight, fromID: "kg", toID: "lb", amount: -70).amount == 70)
        #expect(WidgetConversion.resolve(category: .temperature, fromID: "c", toID: "f", amount: -40).amount == -40)
        #expect(WidgetConversion.resolve(category: .area, fromID: nil, toID: nil, amount: .nan).amount == 1)
    }

    @Test func numbersMatchTheApp() {
        let widget = conversion(.weight, "kg", 70, "lb")
        let appRow = UnitsLogic.rows(for: 70, from: UnitCatalog.unit("kg", in: .weight)!, locale: gb).first { $0.id == "lb" }
        #expect(widget.answerText(locale: gb) == appRow?.copyText)
    }
}

@Suite("Widget tap link")
struct TapeLinkTests {
    @Test func defaultWidgetOpensOnOnePlot() {
        let url = WidgetConversion.standard().link.url
        #expect(url.absoluteString == "tape://open?category=area&unit=plot&amount=1")
    }

    @Test(arguments: [
        TapeLink(category: .area, unitID: "plot", amount: 1),
        TapeLink(category: .volume, unitID: "galus", amount: 2.5),
        TapeLink(category: .temperature, unitID: "c", amount: -18),
        TapeLink(category: .length, unitID: "m", amount: 1.83),
    ])
    func roundTrips(_ link: TapeLink) throws {
        #expect(try #require(TapeLink(url: link.url)) == link)
    }

    @Test func fieldTextIsWhatYoudType() {
        #expect(TapeLink(category: .volume, unitID: "galus", amount: 2.5).fieldText(locale: gb) == "2.5")
        #expect(TapeLink(category: .volume, unitID: "galus", amount: 2.5).fieldText(locale: fr) == "2,5")
        #expect(TapeLink(category: .temperature, unitID: "c", amount: -18).fieldText(locale: gb) == "−18")
        #expect(TapeLink(category: .area, unitID: "ft2", amount: 7200).fieldText(locale: gb) == "7200")
    }

    @Test func rejectsOtherLinks() {
        #expect(TapeLink(url: URL(string: "https://devakintola.com")!) == nil)
        #expect(TapeLink(url: URL(string: "tape://open?category=money")!) == nil)
        #expect(TapeLink(url: URL(string: "tape://other?category=area")!) == nil)
    }

    @Test func unknownUnitOrAmountFallsBack() throws {
        let link = try #require(TapeLink(url: URL(string: "tape://open?category=weight&unit=bogus")!))
        #expect(link.unitID == "kg")
        #expect(link.amount == 1)
    }
}

@Suite("Settings move into the App Group")
struct AppGroupMigrationTests {
    private let old: UserDefaults
    private let new: UserDefaults

    init() {
        let names = ["tape-tests-old-\(UUID().uuidString)", "tape-tests-new-\(UUID().uuidString)"]
        old = UserDefaults(suiteName: names[0])!
        new = UserDefaults(suiteName: names[1])!
        names.forEach { old.removePersistentDomain(forName: $0) }
    }

    @Test func copiesThePlotAndLastAmounts() {
        let plot = PlotSize(preset: .feet50x100)
        TapePersistence.save(plot: plot, to: old)
        TapePersistence.save(amount: "250", for: .weight, to: old)
        old.set("two", forKey: SettingsKeys.decimals)

        TapePersistence.migrate(from: old, to: new)

        #expect(TapePersistence.plot(from: new) == plot)
        #expect(TapePersistence.amount(for: .weight, from: new) == "250")
        #expect(TapePersistence.decimals(from: new) == .two)
    }

    @Test func neverOverwritesTheGroup() {
        TapePersistence.save(amount: "3", for: .area, to: old)
        TapePersistence.save(amount: "5", for: .area, to: new)
        TapePersistence.migrate(from: old, to: new)
        #expect(TapePersistence.amount(for: .area, from: new) == "5")
    }
}
