//
//  PictureLogicTests.swift
//  TapeTests
//
//  The "Picture it" card: which object is chosen at each size, the friendly
//  rounding, how many plots are drawn for each plot size, and the line of
//  text. Locales are pinned.
//

import Testing
import Foundation
@testable import Tape

private let gb = Locale(identifier: "en_GB")

private func unit(_ id: String, _ category: UnitCategory) -> TapeUnit {
    UnitCatalog.unit(id, in: category)!
}

private func picture(_ value: Double, _ id: String, _ category: UnitCategory, plot: PlotSize = .standard) -> Picture {
    PictureLogic.picture(for: value, unit: unit(id, category), plot: plot, locale: gb)
}

private func tally(_ picture: Picture) -> Tally? {
    if case .tally(let tally) = picture.drawing { tally } else { nil }
}

private func plot(_ preset: PlotPreset) -> PlotSize {
    var plot = PlotSize()
    plot.preset = preset
    return plot
}

// MARK: - Choosing the object

@Suite("Comparison choice")
struct ComparisonChoiceTests {
    /// (base value, expected object) either side of every boundary. Nil is
    /// the person and the door.
    static let boundaries: [(UnitCategory, Double, PictureObject?)] = [
        (.area, 3.99, .tile), (.area, 4, .bedroom),
        (.area, 167.2, .bedroom), (.area, 167.3, .plot),
        (.area, 16_053, .plot), (.area, 16_054, .pitch),
        (.weight, 0.0299, .maggiCube), (.weight, 0.03, .egg),
        (.weight, 1.79, .egg), (.weight, 1.8, .eggCrate),
        (.weight, 12.49, .eggCrate), (.weight, 12.5, .riceBag),
        (.weight, 599, .riceBag), (.weight, 600, .car),
        (.length, 0.59, .phone), (.length, 0.6, nil),
        (.length, 2.49, nil), (.length, 2.5, .danfo),
        (.length, 29.9, .danfo), (.length, 30, .pitchLength),
        (.length, 2_999, .pitchLength), (.length, 3_000, .bridge),
        (.volume, 0.0149, .teaspoon), (.volume, 0.015, .tablespoon),
        (.volume, 0.0599, .tablespoon), (.volume, 0.06, .cup),
        (.volume, 0.749, .cup), (.volume, 0.75, .bottle),
        (.volume, 12.49, .bottle), (.volume, 12.5, .jerrycan),
    ]

    @Test(arguments: boundaries)
    func switchesAtTheBoundary(_ category: UnitCategory, _ base: Double, _ expected: PictureObject?) {
        #expect(PictureLogic.object(for: base, category: category, inputUnitID: "", plot: .standard) == expected)
    }

    @Test func areaBoundariesFollowThePlotSize() {
        let small = plot(.feet50x100)   // 464.5 m²
        #expect(PictureLogic.object(for: 120, category: .area, inputUnitID: "", plot: small) == .plot)
        #expect(PictureLogic.object(for: 120, category: .area, inputUnitID: "", plot: .standard) == .bedroom)
    }

    @Test func cookingNeverComparesACupWithACup() {
        // 1 cup: a bottle would be under ¼, so it steps down to tablespoons.
        #expect(PictureLogic.object(for: 0.24, category: .cooking, inputUnitID: "cup", plot: .standard) == .tablespoon)
        // 3 cups is ½ a bottle, so it steps up.
        #expect(PictureLogic.object(for: 0.72, category: .cooking, inputUnitID: "cup", plot: .standard) == .bottle)
        #expect(PictureLogic.object(for: 0.03, category: .cooking, inputUnitID: "tbsp", plot: .standard) == .teaspoon)
        // 1 tsp is ⅓ of a tablespoon; "about ¼" would mislead, so it stays a teaspoon.
        #expect(PictureLogic.object(for: 0.005, category: .cooking, inputUnitID: "tsp", plot: .standard) == .teaspoon)
        // Volume has no cooking units, so a cup stays a cup.
        #expect(PictureLogic.object(for: 0.24, category: .volume, inputUnitID: "l", plot: .standard) == .cup)
    }

    /// Typed anywhere from a pinch to a city, the line never reads as a tiny
    /// decimal, and the drawing never holds more than it can show.
    @Test(arguments: [UnitCategory.area, .weight, .length, .volume, .cooking])
    func neverReadsSilly(_ category: UnitCategory) {
        let base = category.units.first { PictureLogic.baseValue(1, unit: $0, plot: .standard) == 1 }
            ?? unit(category == .cooking ? "l" : "m2", category)
        for exponent in stride(from: -2.0, through: 7.0, by: 0.05) {
            let value = pow(10, exponent)
            let result = PictureLogic.picture(for: value, unit: base, plot: .standard, locale: gb)
            guard let tally = tally(result) else { continue }
            #expect(!result.emphasis.contains("0."), "\(value) in \(category): \(result.sentence)")
            #expect(tally.overflow != nil || tally.drawnCount <= tally.object.maxDrawn)
            let smallest = PictureLogic.ladder(for: category, plot: .standard).first?.object
            if tally.object != smallest {
                #expect(!result.emphasis.hasPrefix("Under"), "\(value) in \(category): \(result.sentence)")
            }
        }
    }
}

// MARK: - Friendly numbers

@Suite("Friendly rounding")
struct FriendlyRoundingTests {
    @Test(arguments: [
        (0.1, nil), (0.125, 0.25), (0.3, 0.25), (0.4, 0.5), (0.7, 0.75),
        (1.4, 1.5), (6.05, 6), (6.13, 6.25), (9.9, 10),
        (10.4, 10), (99.6, 100), (140.4, 140), (833.3, 830), (1_449, 1_400),
    ] as [(Double, Double?)])
    func rounds(_ count: Double, _ expected: Double?) {
        #expect(PictureLogic.friendly(count) == expected)
    }

    @Test(arguments: [(0.25, "¼"), (0.5, "½"), (0.75, "¾"), (1.5, "1½"), (6.25, "6¼"), (6, "6"), (1_400, "1,400")])
    func writesFractionsAsGlyphs(_ value: Double, _ expected: String) {
        #expect(PictureLogic.friendlyText(value, locale: gb) == expected)
    }

    @Test func phrasesCountsLikeASentence() {
        #expect(PictureLogic.countPhrase(1.4, object: .riceBag) == ("About ", "1½ bags", " of rice"))
        #expect(PictureLogic.countPhrase(0.5, object: .riceBag) == ("", "½ a bag", " of rice"))
        #expect(PictureLogic.countPhrase(0.7, object: .plot) == ("About ", "¾ of a plot", " of land"))
        #expect(PictureLogic.countPhrase(1, object: .egg) == ("", "1 egg", ""))
        #expect(PictureLogic.countPhrase(0.3, object: .egg) == ("About ", "¼ of an egg", ""))
        #expect(PictureLogic.countPhrase(0.5, object: .bridge) == ("", "½ of Third Mainland Bridge", ""))
        #expect(PictureLogic.countPhrase(3.2, object: .danfo) == ("About ", "3¼ danfo buses", " long"))
    }

    @Test func underAQuarterDropsTheMeasure() {
        #expect(PictureLogic.countPhrase(0.05, object: .maggiCube) == ("", "Under ¼", " of a Maggi cube"))
        #expect(PictureLogic.countPhrase(0.1, object: .phone) == ("", "Under ¼", " of a phone"))
    }
}

// MARK: - Plots

@Suite("Plot drawing")
struct PlotDrawingTests {
    @Test func oneAcreIsSixPlotsAndASlice() throws {
        let result = picture(1, "acre", .area)
        let drawn = try #require(tally(result))
        #expect(drawn.object == .plot)
        #expect(drawn.whole == 6)
        #expect(abs(drawn.partial - 0.05) < 0.001)
        #expect(drawn.aspect == 2)
        #expect(result.sentence == "About 6 plots of land")
        #expect(result.detail == "60 × 120 ft plots · or ½ a football pitch")
    }

    @Test(arguments: [
        (PlotPreset.feet50x100, 8, 0.712, "About 8¾ plots of land"),
        (.metres18x36, 6, 0.245, "About 6¼ plots of land"),
    ])
    func followsThePlotSetting(_ preset: PlotPreset, _ whole: Int, _ partial: Double, _ sentence: String) throws {
        let result = picture(1, "acre", .area, plot: plot(preset))
        let drawn = try #require(tally(result))
        #expect(drawn.whole == whole)
        #expect(abs(drawn.partial - partial) < 0.001)
        #expect(drawn.aspect == 2)
        #expect(result.sentence == sentence)
    }

    @Test func customPlotsKeepTheirProportionLyingDown() {
        var custom = PlotSize()
        custom.preset = .custom
        custom.customWidth = 100
        custom.customLength = 50
        #expect(PictureObject.plot.aspect(plot: custom) == 2)
        custom.customWidth = 50
        custom.customLength = 75
        custom.customUnit = .metres
        #expect(PictureObject.plot.aspect(plot: custom) == 1.5)
    }

    @Test func threeAcresFillsEighteen() throws {
        let drawn = try #require(tally(picture(3, "acre", .area)))
        #expect(drawn.whole == 18)
        #expect(drawn.overflow == nil)
    }

    @Test func wholePlotsHaveNoSlice() throws {
        let drawn = try #require(tally(picture(2, "plot", .area)))
        #expect(drawn.whole == 2)
        #expect(drawn.partial == 0)
        #expect(drawn.drawnCount == 2)
        #expect(picture(2, "plot", .area).sentence == "2 plots of land")
    }

    @Test func manyPitchesShowACount() throws {
        let result = picture(714_000, "m2", .area)
        let drawn = try #require(tally(result))
        #expect(drawn.object == .pitch)
        #expect(drawn.overflow == "× 100")
        #expect(drawn.drawnCount == 1)
        #expect(result.sentence == "100 football pitches")
    }

    @Test func aSliceSitsAtTheEndOfAFullRow() throws {
        let drawn = try #require(tally(picture(1, "acre", .area)))
        let cells = PictureLogic.cells(for: drawn, width: 300, height: 130, spacing: 6)
        #expect(cells.count == 7)
        #expect(Set(cells.map(\.y)).count == 2)
        let slice = try #require(cells.last)
        #expect(!slice.outlined)
        #expect(abs(slice.fill - 0.05) < 0.001)
        #expect(slice.y == cells[3].y)
        #expect(slice.x > cells[5].x)
        // Centred, slice included.
        let right = slice.x + slice.width * slice.fill
        #expect(abs(cells[0].x - (300 - right)) < 1e-6)
    }

    @Test func aPartFillsTheNextEmptyCell() throws {
        let drawn = try #require(tally(picture(5.5, "plot", .area)))
        let cells = PictureLogic.cells(for: drawn, width: 300, height: 130, spacing: 6)
        #expect(cells.count == 6)
        #expect(cells.last?.outlined == true)
        #expect(cells.last?.fill == 0.5)
    }

    @Test func bagsNeverSlice() throws {
        let drawn = try #require(tally(picture(70, "kg", .weight)))
        let cells = PictureLogic.cells(for: drawn, width: 300, height: 130, spacing: 6)
        #expect(cells.count == 2)
        #expect(cells.allSatisfy { $0.outlined })
    }

    @Test func sixPlotsFitThreeByTwo() {
        let grid = PictureLogic.grid(count: 6, aspect: 2, width: 300, height: 130, spacing: 6)
        #expect(grid.columns == 3)
        #expect(grid.rows == 2)
        #expect(grid.cellWidth == 96)
        #expect(grid.cellHeight == 48)
    }
}

// MARK: - The other categories

@Suite("Pictures")
struct PictureTests {
    @Test func seventyKilosIsABagAndABit() throws {
        let result = picture(70, "kg", .weight)
        let drawn = try #require(tally(result))
        #expect(result.sentence == "About 1½ bags of rice")
        #expect(result.detail == "50 kg bags")
        #expect(drawn.whole == 1)
        #expect(abs(drawn.partial - 0.4) < 1e-9)
        #expect(drawn.labels == ["50 kg", "20 kg"])
    }

    @Test func smallAndLargeWeights() {
        #expect(picture(8, "g", .weight).sentence == "2 Maggi cubes")
        #expect(picture(300, "g", .weight).sentence == "5 eggs")
        #expect(picture(3, "t", .weight).sentence == "2½ cars")
        #expect(picture(70, "t", .weight).sentence == "About 58 cars")
    }

    @Test func sixFeetIsJustUnderADoor() {
        let result = picture(6, "ft", .length)
        #expect(result.sentence == "182.9 cm, a little under a doorway")
        #expect(result.detail == "Doors are about 2.1 m tall")
        guard case .door(let metres) = result.drawing else { Issue.record("Not a door"); return }
        #expect(abs(metres - 1.8288) < 1e-9)
    }

    @Test func metresUseFeetAndInches() {
        #expect(picture(1.83, "m", .length).sentence == "6′ 0″, a little under a doorway")
    }

    @Test(arguments: [(2.1, "about as tall as a doorway"), (2.3, "a little over a doorway"),
                      (1.2, "about ½ a doorway"), (1.5, "about ¾ of a doorway"), (0.6, "about ¼ of a doorway")])
    func doorPhrases(_ metres: Double, _ expected: String) {
        #expect(PictureLogic.doorPhrase(metres: metres, locale: gb) == expected)
    }

    @Test func lengthsBySize() {
        #expect(picture(30, "cm", .length).sentence == "2 phones long")
        #expect(picture(10, "m", .length).sentence == "2 danfo buses long")
        #expect(picture(5.9, "km", .length).sentence == "½ of Third Mainland Bridge")
    }

    @Test func oneCupIsSixteenTablespoons() throws {
        let result = picture(1, "cup", .cooking)
        #expect(result.sentence == "16 tablespoons")
        #expect(try #require(tally(result)).overflow == "× 16")
        #expect(picture(2, "l", .volume).sentence == "About 1¼ bottles of water")
        #expect(picture(50, "l", .volume).sentence == "2 jerrycans")
    }

    @Test(arguments: [(30.0, "c", "30 °C, a hot Lagos afternoon"), (37, "c", "37 °C, body temperature"),
                      (100, "c", "100 °C, water boils"), (0, "c", "0 °C, where water freezes"),
                      (86, "f", "86 °F, a hot Lagos afternoon"), (-18, "c", "−18 °C, freezer cold")])
    func temperatureAnchors(_ value: Double, _ id: String, _ expected: String) {
        #expect(picture(value, id, .temperature).sentence == expected)
    }

    @Test func thermometerFill() {
        #expect(PictureLogic.thermometerFill(celsius: -30) == 0)
        #expect(PictureLogic.thermometerFill(celsius: 35) == 0.5)
        #expect(PictureLogic.thermometerFill(celsius: 180) == 1)
    }

    @Test func zeroShowsAnEmptyOne() throws {
        let result = picture(0, "kg", .weight)
        #expect(result.sentence == "0 bags of rice")
        let drawn = try #require(tally(result))
        #expect(drawn.whole == 0)
        #expect(drawn.partial == 0)
    }
}

// MARK: - Result order

@Suite("Best unit first")
struct ResultOrderTests {
    @Test(arguments: [
        ("acre", UnitCategory.area, "plot"), ("m2", .area, "plot"), ("plot", .area, "m2"),
        ("ft", .length, "cm"), ("m", .length, UnitsLogic.feetAndInchesID), ("km", .length, "mi"),
        ("kg", .weight, "lb"), ("lb", .weight, "kg"), ("g", .weight, "oz"),
        ("c", .temperature, "f"), ("f", .temperature, "c"),
        ("cup", .cooking, "ml"), ("l", .volume, "ml"),
    ])
    func bestUnitLeads(_ input: String, _ category: UnitCategory, _ best: String) {
        #expect(UnitsLogic.rows(for: 1, from: unit(input, category), locale: gb).first?.id == best)
    }

    @Test(arguments: UnitCategory.allCases)
    func everyInputListsEveryOtherUnitOnce(_ category: UnitCategory) {
        for input in category.units {
            let ids = UnitsLogic.rows(for: 1, from: input, locale: gb).map(\.id)
            var expected = Set(category.units.map(\.id))
            expected.remove(input.id)
            if category == .length { expected.insert(UnitsLogic.feetAndInchesID) }
            #expect(ids.count == expected.count, "\(input.id)")
            #expect(Set(ids) == expected, "\(input.id)")
        }
    }

    @Test func seventyKilosListsPoundsThenStone() {
        let rows = UnitsLogic.rows(for: 70, from: unit("kg", .weight), locale: gb)
        #expect(rows.prefix(4).map(\.copyText) == ["154.3 lb", "11.02 st", "70,000 g", "2,469 oz"])
    }
}
