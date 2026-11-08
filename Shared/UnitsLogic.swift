//
//  UnitsLogic.swift
//  Tape
//
//  The pure part of Tape: converting, rounding, formatting, feet and inches,
//  and parsing what was typed. No state, no I/O. Locale and plot size are
//  parameters so the tests can pin them.
//

import Foundation

/// How many decimals to show in a result.
nonisolated enum DecimalPreference: String, CaseIterable, Identifiable, Sendable {
    /// Four significant figures, without ever rounding away whole digits:
    /// 668.9 m², 7,200 ft², 0.1653 ac. Temperatures get up to two decimals.
    case auto
    case zero
    case two
    case four

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: "Auto"
        case .zero: "0"
        case .two: "2"
        case .four: "4"
        }
    }
}

/// One line in the results list.
nonisolated struct ResultRow: Identifiable, Equatable, Sendable {
    /// The unit's id, or `feetAndInchesID` for the split row.
    let id: String
    let name: String
    /// "668.9", or "6′ 0″" for the split row.
    let value: String
    /// "m²". Empty for the split row, whose marks are in `value`.
    let symbol: String

    /// What goes on the clipboard and in the toast: "668.9 m²".
    var copyText: String { symbol.isEmpty ? value : "\(value) \(symbol)" }
}

nonisolated enum UnitsLogic {
    static let feetAndInchesID = "ftin"
    static let significantDigits = 4
    /// Past this many decimals a value is too small to read, and `auto` shows 0.
    static let maxFractionDigits = 9
    /// The true minus, U+2212. A hyphen is shorter and sits too low next to
    /// rounded digits. Typing still accepts a hyphen; everything shown uses this.
    static let minusSign = "\u{2212}"

    // MARK: Converting

    static func convert(_ value: Double, from: TapeUnit, to: TapeUnit, plot: PlotSize = .standard) -> Double {
        precondition(from.category == to.category, "Can't convert \(from.category) to \(to.category)")
        if from == to { return value }
        if from.category == .temperature {
            return convertTemperature(value, from: from.id, to: to.id)
        }
        guard let source = UnitCatalog.dimension(for: from, plot: plot),
              let target = UnitCatalog.dimension(for: to, plot: plot)
        else { preconditionFailure("No dimension for \(from.id) or \(to.id)") }
        let base = source.converter.baseUnitValue(fromValue: value)
        return target.converter.value(fromBaseUnitValue: base)
    }

    /// Temperature scales have different zeros, so this is a formula with an
    /// offset, not a ratio: 0 °C is 32 °F, not 0 °F.
    static func convertTemperature(_ value: Double, from: String, to: String) -> Double {
        let celsius: Double = switch from {
        case "f": (value - 32) * 5 / 9
        case "k": value - 273.15
        default: value
        }
        return switch to {
        case "f": celsius * 9 / 5 + 32
        case "k": celsius + 273.15
        default: celsius
        }
    }

    // MARK: Rounding

    /// Fraction digits for `value` in `unit`. Fixed preferences are exact;
    /// `auto` keeps four significant figures but never drops whole digits.
    static func fractionDigits(for value: Double, unit: TapeUnit, preference: DecimalPreference) -> (min: Int, max: Int) {
        switch preference {
        case .zero: return (0, 0)
        case .two: return (2, 2)
        case .four: return (4, 4)
        case .auto:
            if unit.category == .temperature { return (0, 2) }
            let magnitude = abs(value)
            guard magnitude > 0, magnitude.isFinite else { return (0, 0) }
            let leading = Int(floor(log10(magnitude)))
            return (0, min(maxFractionDigits, max(0, significantDigits - 1 - leading)))
        }
    }

    /// Rounds through `Decimal`, half up, so 0.1 + 0.2 shows as 0.3 and not
    /// 0.30000000000000004.
    static func rounded(_ value: Double, places: Int) -> Decimal {
        var input = decimal(value)
        var result = Decimal()
        NSDecimalRound(&result, &input, places, .plain)
        return result
    }

    /// The shortest string form, so 668.901888 stays 668.901888 instead of
    /// picking up binary noise on the way into `Decimal`.
    static func decimal(_ value: Double) -> Decimal {
        Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(value)
    }

    // MARK: Formatting

    /// A decimal formatter in `locale` that writes the true minus.
    static func numberFormatter(locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.minusSign = minusSign
        return formatter
    }

    /// The number alone, with the locale's grouping and decimal mark: "668.9",
    /// "7,200", "0.1653", "−40". Never "−0".
    static func formatNumber(
        _ value: Double,
        unit: TapeUnit,
        preference: DecimalPreference = .auto,
        locale: Locale = .current
    ) -> String {
        guard value.isFinite else { return "—" }
        let digits = fractionDigits(for: value, unit: unit, preference: preference)
        var number = rounded(value, places: digits.max)
        if number.isZero { number = 0 }
        let formatter = numberFormatter(locale: locale)
        formatter.minimumFractionDigits = digits.min
        formatter.maximumFractionDigits = digits.max
        formatter.roundingMode = .halfUp
        return formatter.string(from: number as NSDecimalNumber) ?? "\(number)"
    }

    /// "668.9 m²", "1 plot", "2.5 plots".
    static func format(
        _ value: Double,
        unit: TapeUnit,
        preference: DecimalPreference = .auto,
        locale: Locale = .current
    ) -> String {
        "\(formatNumber(value, unit: unit, preference: preference, locale: locale)) \(unit.symbol(for: value))"
    }

    // MARK: Feet and inches

    /// Splits a length in metres into whole feet and inches to a tenth, carrying
    /// so 5′ 11.96″ becomes 6′ 0″ rather than 5′ 12″.
    static func feetAndInches(metres: Double) -> (feet: Int, inches: Decimal, negative: Bool) {
        let totalInches = abs(metres) / 0.0254
        let tenths = (totalInches * 10).rounded()
        let feet = Int(tenths / 120)
        let inchTenths = tenths - Double(feet) * 120
        let inches = Decimal(Int(inchTenths)) / 10
        return (feet, inches, metres < 0 && tenths > 0)
    }

    /// "6′ 0″", "5′ 9.3″", in the locale's decimal mark.
    static func formatFeetAndInches(metres: Double, locale: Locale = .current) -> String {
        let split = feetAndInches(metres: metres)
        let formatter = numberFormatter(locale: locale)
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        let feet = formatter.string(from: split.feet as NSNumber) ?? "\(split.feet)"
        let inches = formatter.string(from: split.inches as NSDecimalNumber) ?? "\(split.inches)"
        return "\(split.negative ? minusSign : "")\(feet)′ \(inches)″"
    }

    // MARK: Results

    /// Every unit in the category except the one typed in, most useful first
    /// (see `UnitCatalog.resultOrder`). Length includes a feet-and-inches row.
    static func rows(
        for value: Double,
        from unit: TapeUnit,
        plot: PlotSize = .standard,
        preference: DecimalPreference = .auto,
        locale: Locale = .current
    ) -> [ResultRow] {
        UnitCatalog.resultOrder(from: unit).compactMap { id in
            if id == feetAndInchesID {
                let metres = convert(value, from: unit, to: UnitCatalog.unit("m", in: .length)!)
                return ResultRow(
                    id: feetAndInchesID,
                    name: "Feet and inches",
                    value: formatFeetAndInches(metres: metres, locale: locale),
                    symbol: ""
                )
            }
            guard let target = UnitCatalog.unit(id, in: unit.category), target != unit else { return nil }
            let converted = convert(value, from: unit, to: target, plot: plot)
            return ResultRow(
                id: target.id,
                name: target.name,
                value: formatNumber(converted, unit: target, preference: preference, locale: locale),
                symbol: target.symbol(for: converted)
            )
        }
    }

    // MARK: Plot

    /// "60 × 120 ft"
    static func plotDimensions(_ plot: PlotSize, locale: Locale = .current) -> String {
        let s = plot.sides
        let formatter = numberFormatter(locale: locale)
        formatter.maximumFractionDigits = 2
        let width = formatter.string(from: s.width as NSNumber) ?? "\(s.width)"
        let length = formatter.string(from: s.length as NSNumber) ?? "\(s.length)"
        return "\(width) × \(length) \(s.unit.symbol)"
    }

    /// "60 × 120 ft · 668.9 m²"
    static func plotSummary(_ plot: PlotSize, locale: Locale = .current) -> String {
        let squareMetres = UnitCatalog.unit("m2", in: .area)!
        return "\(plotDimensions(plot, locale: locale)) · \(format(plot.squareMetres, unit: squareMetres, locale: locale))"
    }

    // MARK: Parsing input

    /// What the user typed, as a number. Accepts the locale's decimal mark,
    /// ignores its grouping mark, and takes a leading minus. Nil for empty or
    /// malformed input.
    static func parseAmount(_ text: String, locale: Locale = .current) -> Double? {
        let decimalMark = locale.decimalSeparator ?? "."
        let groupMark = locale.groupingSeparator ?? ","
        var cleaned = text.trimmingCharacters(in: .whitespaces)
        let negative = startsWithMinus(cleaned)
        if negative { cleaned.removeFirst() }
        if groupMark != decimalMark {
            cleaned = cleaned.replacingOccurrences(of: groupMark, with: "")
        }
        cleaned = cleaned.replacingOccurrences(of: decimalMark, with: ".")
        guard !cleaned.isEmpty,
              cleaned.allSatisfy({ ($0.isASCII && $0.isNumber) || $0 == "." }),
              cleaned.filter({ $0 == "." }).count <= 1,
              cleaned.contains(where: \.isNumber),
              let number = Double(cleaned)
        else { return nil }
        return negative ? -number : number
    }

    /// A hyphen or a true minus at the start.
    static func startsWithMinus(_ text: String) -> Bool {
        text.hasPrefix("-") || text.hasPrefix(minusSign)
    }

    /// What the amount field keeps as you type: an optional leading minus (only
    /// where `allowsNegative`, and always shown as the true minus), digits and one decimal mark, at most
    /// `maxIntegerDigits` whole digits and `maxFractionDigits` after the mark.
    /// Leading zeros go; ".5" becomes "0.5".
    static func sanitizeAmount(
        _ text: String,
        allowsNegative: Bool = false,
        maxFractionDigits: Int = 6,
        maxIntegerDigits: Int = 12,
        locale: Locale = .current
    ) -> String {
        let mark = Character(locale.decimalSeparator ?? ".")
        let negative = allowsNegative && startsWithMinus(text)
        var whole = ""
        var fraction = ""
        var seenMark = false
        for character in text {
            if character.isASCII, character.isNumber {
                if seenMark {
                    if fraction.count < maxFractionDigits { fraction.append(character) }
                } else if whole.count < maxIntegerDigits {
                    whole.append(character)
                }
            } else if character == mark, !seenMark, maxFractionDigits > 0 {
                seenMark = true
            }
        }
        while whole.count > 1, whole.first == "0" { whole.removeFirst() }
        if seenMark, whole.isEmpty { whole = "0" }
        let number = seenMark ? whole + String(mark) + fraction : whole
        return negative ? minusSign + number : number
    }

    /// Flips the sign of what's typed, for the ± key on temperature.
    static func toggleSign(_ text: String) -> String {
        if startsWithMinus(text) { return String(text.dropFirst()) }
        return minusSign + text
    }
}
