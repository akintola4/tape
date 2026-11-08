//
//  PictureLogic.swift
//  Tape
//
//  The "Picture it" card: which everyday thing to compare an amount with, how
//  many of it to draw, and the plain-English line above the drawing. Pure, so
//  every threshold is tested. The objects are sized in each category's base
//  unit: square metres, kilograms, metres and litres.
//

import Foundation

/// Something you already know the size of.
nonisolated enum PictureObject: String, CaseIterable, Sendable {
    case tile, bedroom, plot, pitch
    case maggiCube, egg, eggCrate, riceBag, car
    case phone, danfo, pitchLength, bridge
    case teaspoon, tablespoon, cup, bottle, jerrycan

    /// In the category's base unit. A plot is whatever the setting says.
    func size(plot: PlotSize) -> Double {
        switch self {
        case .tile: 0.36                        // 60 × 60 cm
        case .bedroom: 3.6576 * 3.6576          // 12 × 12 ft
        case .plot: plot.isValid ? plot.squareMetres : PlotSize.standard.squareMetres
        case .pitch: 105 * 68                   // FIFA's recommended pitch
        case .maggiCube: 0.004
        case .egg: 0.06
        case .eggCrate: 1.8                     // 30 eggs
        case .riceBag: 50
        case .car: 1200
        case .phone: 0.15
        case .danfo: 5
        case .pitchLength: 105
        case .bridge: 11_800                    // Third Mainland Bridge
        case .teaspoon: 0.005
        case .tablespoon: 0.015
        case .cup: 0.24
        case .bottle: 1.5
        case .jerrycan: 25
        }
    }

    /// Width over height, as drawn. Plots keep their real proportion, drawn
    /// lying down: a 60 × 120 ft plot is a 2:1 block.
    func aspect(plot: PlotSize) -> Double {
        switch self {
        case .plot:
            let sides = (plot.isValid ? plot : .standard).sides
            return max(sides.width, sides.length) / min(sides.width, sides.length)
        case .tile, .bedroom, .maggiCube: return 1
        case .pitch, .pitchLength: return 105.0 / 68
        case .egg: return 0.78
        case .eggCrate: return 1.2
        case .riceBag: return 0.8
        case .car: return 2.2
        case .phone: return 2.1
        case .danfo: return 2.3
        case .bridge: return 6
        case .teaspoon, .tablespoon: return 3
        case .cup: return 1.1
        case .bottle: return 0.38
        case .jerrycan: return 0.8
        }
    }

    /// Containers fill from the bottom; everything else shows a slice.
    var fillsFromBottom: Bool {
        switch self {
        case .riceBag, .cup, .bottle, .jerrycan: true
        default: false
        }
    }

    /// Past this many the drawing shows one with a count instead.
    var maxDrawn: Int {
        switch self {
        case .egg, .pitchLength: 30
        case .plot: 24
        case .bedroom: 16
        case .bridge: 6
        default: 12
        }
    }

    var singular: String {
        switch self {
        case .tile: "floor tile"
        case .bedroom: "bedroom"
        case .plot: "plot"
        case .pitch, .pitchLength: "football pitch"
        case .maggiCube: "Maggi cube"
        case .egg: "egg"
        case .eggCrate: "crate"
        case .riceBag: "bag"
        case .car: "car"
        case .phone: "phone"
        case .danfo: "danfo bus"
        case .bridge: "Third Mainland Bridge"
        case .teaspoon: "teaspoon"
        case .tablespoon: "tablespoon"
        case .cup: "cup"
        case .bottle: "bottle"
        case .jerrycan: "jerrycan"
        }
    }

    var plural: String {
        switch self {
        case .pitch, .pitchLength: "football pitches"
        case .danfo: "danfo buses"
        case .bridge: "Third Mainland Bridges"
        default: singular + "s"
        }
    }

    /// "a", "an", or nothing for a name.
    var article: String {
        switch self {
        case .egg: "an"
        case .bridge: ""
        default: "a"
        }
    }

    /// What follows the count: "of land" in "About 6 plots of land".
    var trail: String {
        switch self {
        case .plot: " of land"
        case .riceBag: " of rice"
        case .eggCrate: " of eggs"
        case .bottle: " of water"
        case .phone, .danfo, .pitchLength: " long"
        default: ""
        }
    }

    /// The cooking unit this object is, if it is one. Comparing 1 cup with
    /// 1 cup tells you nothing, so the ladder steps past it.
    var unitID: String? {
        switch self {
        case .teaspoon: "tsp"
        case .tablespoon: "tbsp"
        case .cup: "cup"
        default: nil
        }
    }
}

/// Some number of one object: whole ones and a part of the next.
nonisolated struct Tally: Equatable, Sendable {
    let object: PictureObject
    let aspect: Double
    /// Whole objects drawn.
    let whole: Int
    /// How much of the next one is drawn, 0 ..< 1.
    let partial: Double
    /// "× 140" when there are too many to draw; then one is drawn.
    var overflow: String? = nil
    /// Text inside each drawn object, if any: "50 kg", "20 kg".
    var labels: [String] = []

    /// Cells in the grid: the whole ones, plus one for the part.
    var drawnCount: Int { whole + (partial > 0 ? 1 : 0) }
}

nonisolated enum Drawing: Equatable, Sendable {
    case tally(Tally)
    /// A person this tall standing next to a 2.1 m door.
    case door(personMetres: Double)
    /// How full the tube is, 0 ... 1, from −30 °C to 100 °C.
    case thermometer(fill: Double)
}

nonisolated struct Picture: Equatable, Sendable {
    /// "About ", or empty.
    let lead: String
    /// The part in the accent colour: "6 plots", "182.9 cm".
    let emphasis: String
    /// " of land", ", a little under a doorway".
    let trail: String
    /// The small line: "60 × 120 ft plots · or ½ a football pitch".
    let detail: String
    let drawing: Drawing

    var sentence: String { lead + emphasis + trail }
}

nonisolated enum PictureLogic {
    static let doorMetres = 2.1
    /// The thermometer runs from here to 100 °C.
    static let thermometerFloor = -30.0

    // MARK: Choosing

    /// Rungs from small to large: use the first whose upper bound is above
    /// the value. Bounds sit where the next object reads as at least ¼ of one
    /// and the current one still fits its grid, so nothing reads as
    /// "0.0001 bags".
    static func ladder(for category: UnitCategory, plot: PlotSize) -> [(object: PictureObject?, below: Double)] {
        let plotSize = PictureObject.plot.size(plot: plot)
        return switch category {
        case .area:
            [(.tile, 4), (.bedroom, plotSize / 4), (.plot, plotSize * 24), (.pitch, .infinity)]
        case .weight:
            [(.maggiCube, 0.03), (.egg, 1.8), (.eggCrate, 12.5), (.riceBag, 600), (.car, .infinity)]
        case .length:
            // nil is the person and the door.
            [(.phone, 0.6), (nil, 2.5), (.danfo, 30), (.pitchLength, 3000), (.bridge, .infinity)]
        case .volume, .cooking:
            [(.teaspoon, 0.015), (.tablespoon, 0.06), (.cup, 0.75), (.bottle, 12.5), (.jerrycan, .infinity)]
        case .temperature:
            []
        }
    }

    /// What `base` (in the category's base unit) is compared with. Nil means
    /// the person and the door.
    static func object(for base: Double, category: UnitCategory, inputUnitID: String, plot: PlotSize) -> PictureObject? {
        let rungs = ladder(for: category, plot: plot)
        guard let index = rungs.firstIndex(where: { base < $0.below }) else { return rungs.last?.object }
        let chosen = rungs[index].object
        guard category == .cooking, let chosen, chosen.unitID == inputUnitID else { return chosen }
        // Step up only if the friendly count stays honest: 1 tsp is ⅓ of a
        // tablespoon, and "about ¼" would be 25% out.
        if rungs.indices.contains(index + 1), let larger = rungs[index + 1].object {
            let count = base / larger.size(plot: plot)
            if let rounded = friendly(count), abs(rounded - count) / count <= 0.15 {
                return larger
            }
        }
        if index > 0, let smaller = rungs[index - 1].object { return smaller }
        return chosen
    }

    /// The object a blank or zero amount shows, empty.
    static func restingObject(for category: UnitCategory) -> PictureObject {
        switch category {
        case .area: .plot
        case .weight: .riceBag
        case .length: .phone
        case .volume, .cooking, .temperature: .cup
        }
    }

    // MARK: The picture

    static func picture(
        for value: Double,
        unit: TapeUnit,
        plot: PlotSize = .standard,
        locale: Locale = .current
    ) -> Picture {
        if unit.category == .temperature {
            return temperature(value, unit: unit, locale: locale)
        }
        let base = baseValue(value, unit: unit, plot: plot)
        guard base > 0, base.isFinite else {
            let object = restingObject(for: unit.category)
            return Picture(
                lead: "",
                emphasis: "0 \(object.plural)",
                trail: object.trail,
                detail: detail(for: object, base: 0, plot: plot, locale: locale),
                drawing: .tally(Tally(object: object, aspect: object.aspect(plot: plot), whole: 0, partial: 0))
            )
        }
        guard let object = object(for: base, category: unit.category, inputUnitID: unit.id, plot: plot) else {
            return door(metres: base, unit: unit, value: value, plot: plot, locale: locale)
        }
        let count = base / object.size(plot: plot)
        let phrase = countPhrase(count, object: object, locale: locale)
        return Picture(
            lead: phrase.lead,
            emphasis: phrase.emphasis,
            trail: phrase.trail,
            detail: detail(for: object, base: base, plot: plot, locale: locale),
            drawing: .tally(tally(count, object: object, plot: plot, locale: locale))
        )
    }

    /// `value` in the category's base unit: m², kg, m or L.
    static func baseValue(_ value: Double, unit: TapeUnit, plot: PlotSize) -> Double {
        guard let dimension = UnitCatalog.dimension(for: unit, plot: plot) else { return value }
        return dimension.converter.baseUnitValue(fromValue: value)
    }

    /// How many to draw. A part under 1% isn't visible, so it's dropped (and
    /// one within 1% of whole rounds up).
    static func tally(_ count: Double, object: PictureObject, plot: PlotSize, locale: Locale = .current) -> Tally {
        var whole = Int(count.rounded(.down))
        var partial = count - Double(whole)
        if partial < 0.01 { partial = 0 }
        if partial > 0.99 { whole += 1; partial = 0 }
        let aspect = object.aspect(plot: plot)
        if whole + (partial > 0 ? 1 : 0) > object.maxDrawn {
            let amount = friendlyText(friendly(count) ?? count, locale: locale)
            return Tally(object: object, aspect: aspect, whole: 1, partial: 0, overflow: "× \(amount)")
        }
        var labels: [String] = []
        if object == .riceBag, whole + (partial > 0 ? 1 : 0) <= 3 {
            let bag = Int(object.size(plot: plot))
            labels = Array(repeating: "\(bag) kg", count: whole)
            if partial > 0 { labels.append("\(Int((partial * Double(bag)).rounded())) kg") }
        }
        return Tally(object: object, aspect: aspect, whole: whole, partial: partial, labels: labels)
    }

    // MARK: Friendly numbers

    /// The count as a person would say it: quarters under 10, whole numbers
    /// under 100, two significant figures above. Nil under ⅛, which is
    /// "under ¼".
    static func friendly(_ count: Double) -> Double? {
        guard count >= 0.125 else { return nil }
        if count < 10 { return (count * 4).rounded() / 4 }
        if count < 100 { return count.rounded() }
        let magnitude = pow(10, floor(log10(count)) - 1)
        return (count / magnitude).rounded() * magnitude
    }

    /// "6", "1½", "¾", "1,400".
    static func friendlyText(_ value: Double, locale: Locale = .current) -> String {
        let whole = Int(value.rounded(.down))
        let glyph: String = switch value - Double(whole) {
        case 0.24...0.26: "¼"
        case 0.49...0.51: "½"
        case 0.74...0.76: "¾"
        default: ""
        }
        if whole == 0, !glyph.isEmpty { return glyph }
        let formatter = UnitsLogic.numberFormatter(locale: locale)
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: whole as NSNumber) ?? "\(whole)") + glyph
    }

    /// "About " + "6 plots" + " of land". "About" goes when the count is exact.
    static func countPhrase(_ count: Double, object: PictureObject, locale: Locale = .current) -> (lead: String, emphasis: String, trail: String) {
        guard let rounded = friendly(count) else {
            let ofTrail = object.trail.hasPrefix(" of") ? object.trail : ""
            return ("", "Under ¼", " of \(withArticle(object))\(ofTrail)")
        }
        let lead = abs(rounded - count) < 1e-6 * max(1, count) ? "" : "About "
        let text = friendlyText(rounded, locale: locale)
        let noun: String = switch rounded {
        case 0.5: object.article.isEmpty ? "½ of \(object.singular)" : "½ \(withArticle(object))"
        case ..<1: "\(text) of \(withArticle(object))"
        case 1: "1 \(object.singular)"
        default: "\(text) \(object.plural)"
        }
        return (lead, noun, object.trail)
    }

    private static func withArticle(_ object: PictureObject) -> String {
        object.article.isEmpty ? object.singular : "\(object.article) \(object.singular)"
    }

    // MARK: Details

    static func detail(for object: PictureObject, base: Double, plot: PlotSize, locale: Locale = .current) -> String {
        let n = { (value: Double) in number(value, locale: locale) }
        switch object {
        case .tile: return "60 × 60 cm tiles"
        case .bedroom: return "12 × 12 ft bedrooms"
        case .plot:
            let dims = "\(UnitsLogic.plotDimensions(plot.isValid ? plot : .standard, locale: locale)) plots"
            let pitches = base / PictureObject.pitch.size(plot: plot)
            guard friendly(pitches) != nil else { return dims }
            return "\(dims) · or \(countPhrase(pitches, object: .pitch, locale: locale).emphasis)"
        case .pitch: return "105 × 68 m pitches"
        case .maggiCube: return "A cube is \(n(4)) g"
        case .egg: return "An egg is about \(n(60)) g"
        case .eggCrate: return "30 eggs, about \(n(1.8)) kg"
        case .riceBag: return "\(n(50)) kg bags"
        case .car: return "A small car is about \(n(1200)) kg"
        case .phone: return "A phone is about \(n(15)) cm"
        case .danfo: return "A danfo is about \(n(5)) m"
        case .pitchLength: return "A pitch is \(n(105)) m long"
        case .bridge: return "Third Mainland Bridge is \(n(11.8)) km"
        case .teaspoon: return "\(n(5)) mL each"
        case .tablespoon: return "\(n(15)) mL each"
        case .cup: return "\(n(240)) mL each"
        case .bottle: return "\(n(1.5)) L bottles"
        case .jerrycan: return "\(n(25)) L jerrycans"
        }
    }

    private static func number(_ value: Double, locale: Locale) -> String {
        let formatter = UnitsLogic.numberFormatter(locale: locale)
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSNumber) ?? "\(value)"
    }

    // MARK: Person and door

    /// Heights, 0.6 to 2.5 m: the most useful unit for it, then how it
    /// stands against a door.
    static func door(metres: Double, unit: TapeUnit, value: Double, plot: PlotSize, locale: Locale) -> Picture {
        let best = UnitsLogic.rows(for: value, from: unit, plot: plot, locale: locale).first?.copyText
            ?? UnitsLogic.format(value, unit: unit, locale: locale)
        return Picture(
            lead: "",
            emphasis: best,
            trail: ", " + doorPhrase(metres: metres, locale: locale),
            detail: "Doors are about \(number(doorMetres, locale: locale)) m tall",
            drawing: .door(personMetres: metres)
        )
    }

    static func doorPhrase(metres: Double, locale: Locale = .current) -> String {
        let ratio = metres / doorMetres
        switch ratio {
        case 0.965...1.035: return "about as tall as a doorway"
        case 0.8..<0.965: return "a little under a doorway"
        case 1.035...: return "a little over a doorway"
        default:
            let part = friendly(ratio) ?? 0.25
            return "about " + (part == 0.5 ? "½ a doorway" : "\(friendlyText(part, locale: locale)) of a doorway")
        }
    }

    // MARK: Temperature

    /// From the top down: the first anchor at or below the temperature wins.
    static let anchors: [(from: Double, phrase: String, detail: String)] = [
        (250, "hotter than an oven", "Cakes bake at about 180 °C"),
        (150, "oven hot", "Cakes bake at about 180 °C"),
        (100.5, "hotter than boiling water", "Water boils at 100 °C"),
        (99.5, "water boils", "At sea level, anyway"),
        (75, "nearly boiling", "Water boils at 100 °C"),
        (48, "too hot to keep a hand in", "Hot tap water runs at about 50 °C"),
        (39, "a hot bath", "Bath water is about 40 °C"),
        (35, "body temperature", "A healthy body is about 37 °C"),
        (27, "a hot Lagos afternoon", "Lagos afternoons run 30 to 33 °C"),
        (20, "room temperature", "Most rooms sit at 20 to 25 °C"),
        (10, "a cool harmattan morning", "Harmattan mornings up north drop to about 12 °C"),
        (0.5, "fridge cold", "Fridges run at about 4 °C"),
        (-0.5, "where water freezes", "Ice melts at 0 °C"),
        (-10, "below freezing", "Water freezes at 0 °C"),
        (-30, "freezer cold", "Freezers run at about −18 °C"),
        (-273.15, "colder than a freezer", "Freezers run at about −18 °C"),
        (-.infinity, "below absolute zero", "Nothing gets colder than −273.15 °C"),
    ]

    static func anchor(celsius: Double) -> (phrase: String, detail: String) {
        let match = anchors.first { celsius >= $0.from } ?? anchors[anchors.count - 1]
        return (match.phrase, match.detail)
    }

    static func thermometerFill(celsius: Double) -> Double {
        min(1, max(0, (celsius - thermometerFloor) / (100 - thermometerFloor)))
    }

    static func temperature(_ value: Double, unit: TapeUnit, locale: Locale) -> Picture {
        let celsius = UnitsLogic.convertTemperature(value, from: unit.id, to: "c")
        let anchor = anchor(celsius: celsius)
        return Picture(
            lead: "",
            emphasis: UnitsLogic.format(value, unit: unit, locale: locale),
            trail: ", " + anchor.phrase,
            detail: anchor.detail,
            drawing: .thermometer(fill: thermometerFill(celsius: celsius))
        )
    }

    // MARK: Layout

    /// One drawn object: its frame, how full it is, and whether its outline
    /// shows (a part in its own cell does; a slice at the end of a row doesn't).
    struct Cell: Equatable, Sendable {
        let x, y, width, height: Double
        let fill: Double
        let outlined: Bool
    }

    /// Where every object in `tally` goes in a `width` × `height` box,
    /// centred. Whole ones fill a grid; the part goes in the next cell, or,
    /// for slices when the last row is full, as a thin slice at that row's
    /// end, so 6.05 plots stays a 3 × 2 grid rather than gaining a row for 5%.
    static func cells(for tally: Tally, width: Double, height: Double, spacing: Double,
                      maxHeight: Double = .infinity, maxWidth: Double = .infinity) -> [Cell] {
        let count = max(1, tally.drawnCount)
        var columns: Int, rows: Int, cellWidth: Double
        var sliceAtRowEnd = false
        let plain = grid(count: count, aspect: tally.aspect, width: width, height: height, spacing: spacing, maxHeight: maxHeight, maxWidth: maxWidth)
        (columns, rows, cellWidth) = (plain.columns, plain.rows, plain.cellWidth)

        if tally.partial > 0, tally.whole > 0, !tally.object.fillsFromBottom {
            let wholes = grid(count: tally.whole, aspect: tally.aspect, width: width, height: height, spacing: spacing, maxHeight: maxHeight, maxWidth: maxWidth)
            if tally.whole % wholes.columns == 0 {
                let columnsWithSlice = Double(wholes.columns) + tally.partial
                let fitted = min(wholes.cellWidth, (width - Double(wholes.columns) * spacing) / columnsWithSlice)
                if fitted > cellWidth {
                    (columns, rows, cellWidth) = (wholes.columns, wholes.rows, fitted)
                    sliceAtRowEnd = true
                }
            } else if wholes.cellWidth > cellWidth {
                (columns, rows, cellWidth) = (wholes.columns, wholes.rows, wholes.cellWidth)
            }
        }

        let cellHeight = cellWidth / tally.aspect
        var gridWidth = Double(columns) * cellWidth + Double(columns - 1) * spacing
        if sliceAtRowEnd { gridWidth += spacing + tally.partial * cellWidth }
        let gridHeight = Double(rows) * cellHeight + Double(rows - 1) * spacing
        let originX = (width - gridWidth) / 2
        let originY = (height - gridHeight) / 2

        return (0..<count).map { index in
            let isPart = index == tally.whole && tally.partial > 0
            let column: Int, row: Int
            if isPart && sliceAtRowEnd {
                (column, row) = (columns, rows - 1)
            } else {
                (column, row) = (index % columns, index / columns)
            }
            return Cell(
                x: originX + Double(column) * (cellWidth + spacing),
                y: originY + Double(row) * (cellHeight + spacing),
                width: cellWidth,
                height: cellHeight,
                fill: index < tally.whole ? 1 : tally.partial,
                outlined: !(isPart && sliceAtRowEnd)
            )
        }
    }

    // MARK: Grid

    /// The largest cell that fits `count` cells of `aspect` (width / height)
    /// into `width` × `height`, and the columns and rows that give it.
    static func grid(count: Int, aspect: Double, width: Double, height: Double, spacing: Double,
                     maxHeight: Double = .infinity, maxWidth: Double = .infinity)
        -> (columns: Int, rows: Int, cellWidth: Double, cellHeight: Double) {
        let count = max(1, count)
        var best = (columns: 1, rows: count, cellWidth: 0.0, cellHeight: 0.0)
        for columns in 1...count {
            let rows = Int((Double(count) / Double(columns)).rounded(.up))
            let fitWidth = (width - Double(columns - 1) * spacing) / Double(columns)
            let fitHeight = min(maxHeight, (height - Double(rows - 1) * spacing) / Double(rows))
            let cellWidth = min(fitWidth, fitHeight * aspect, maxWidth)
            if cellWidth > best.cellWidth {
                best = (columns, rows, cellWidth, cellWidth / aspect)
            }
        }
        return best
    }
}
