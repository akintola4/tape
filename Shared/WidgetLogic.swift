//
//  WidgetLogic.swift
//  Tape
//
//  Shared between the app AND the widget extension.
//
//  What a widget shows: one conversion the user picked (1 plot in square
//  metres unless they change it), worked out with the same `UnitsLogic` as the
//  app so the numbers match. Also the tape:// link a tap on the widget opens.
//  Pure, so the text for every widget size is tested.
//

import Foundation

nonisolated struct WidgetConversion: Equatable, Sendable {
    let from: TapeUnit
    let amount: Double
    let to: TapeUnit
    var plot: PlotSize = .standard
    var decimals: DecimalPreference = .auto

    var category: UnitCategory { from.category }

    /// 1 plot in square metres, with the plot from the settings.
    static func standard(plot: PlotSize = .standard, decimals: DecimalPreference = .auto) -> WidgetConversion {
        resolve(category: .area, fromID: "plot", toID: "m2", amount: 1, plot: plot, decimals: decimals)
    }

    /// Builds a conversion from what the widget's settings hold, which can
    /// disagree with each other: changing the category leaves the units from
    /// the old one behind. A unit that isn't in the category falls back to the
    /// category's usual one, and the answer unit is never the same as the input.
    static func resolve(
        category: UnitCategory?,
        fromID: String?,
        toID: String?,
        amount: Double?,
        plot: PlotSize = .standard,
        decimals: DecimalPreference = .auto
    ) -> WidgetConversion {
        let category = category ?? .area
        let from = UnitCatalog.unitOrDefault(fromID, in: category)
        let to = toID.flatMap { UnitCatalog.unit($0, in: category) }.flatMap { $0 == from ? nil : $0 }
            ?? defaultAnswerUnit(for: from)
        var amount = amount.flatMap { $0.isFinite ? $0 : nil } ?? 1
        if !category.allowsNegative { amount = abs(amount) }
        return WidgetConversion(from: from, amount: amount, to: to, plot: plot, decimals: decimals)
    }

    /// The first real unit in the app's results order: square metres for
    /// plots, pounds for kilograms, feet for metres.
    static func defaultAnswerUnit(for from: TapeUnit) -> TapeUnit {
        UnitCatalog.resultOrder(from: from).lazy.compactMap { UnitCatalog.unit($0, in: from.category) }.first!
    }

    // MARK: Values

    var result: Double { UnitsLogic.convert(amount, from: from, to: to, plot: plot) }

    /// "1 plot", "2.5 plots", "−18 °C".
    func inputText(locale: Locale = .current) -> String {
        UnitsLogic.format(amount, unit: from, locale: locale)
    }

    /// "668.9", in the decimals the app is set to.
    func answerNumber(locale: Locale = .current) -> String {
        UnitsLogic.formatNumber(result, unit: to, preference: decimals, locale: locale)
    }

    /// "m²"
    var answerSymbol: String { to.symbol(for: result) }

    /// "668.9 m²"
    func answerText(locale: Locale = .current) -> String {
        "\(answerNumber(locale: locale)) \(answerSymbol)"
    }

    /// "1 plot = 668.9 m²", for the inline Lock Screen widget.
    func inlineText(locale: Locale = .current) -> String {
        "\(inputText(locale: locale)) = \(answerText(locale: locale))"
    }

    /// "669", for the round Lock Screen widget: three significant figures,
    /// and K or M past ten thousand.
    func compactNumber(locale: Locale = .current) -> String {
        Self.compact(result, locale: locale)
    }

    /// The next most useful unit after the answer, for the line under it on
    /// the Home Screen: "7,200 ft²" for a plot shown in square metres.
    func secondaryText(locale: Locale = .current) -> String? {
        UnitsLogic.rows(for: amount, from: from, plot: plot, preference: decimals, locale: locale)
            .first { $0.id != to.id }?
            .copyText
    }

    /// "1 plot is 668.9 square metres"
    func spokenText(locale: Locale = .current) -> String {
        "\(inputText(locale: locale)) is \(answerNumber(locale: locale)) \(to.name.lowercased())"
    }

    var link: TapeLink { TapeLink(category: category, unitID: from.id, amount: amount) }

    static func compact(_ value: Double, locale: Locale = .current) -> String {
        guard value.isFinite else { return "—" }
        let magnitude = abs(value)
        let (scaled, suffix): (Double, String) = switch magnitude {
        case 1e9...: (value / 1e9, "B")
        case 1e6...: (value / 1e6, "M")
        case 1e4...: (value / 1e3, "K")
        default: (value, "")
        }
        let places: Int
        if abs(scaled) > 0 {
            let leading = Int(floor(log10(abs(scaled))))
            places = min(UnitsLogic.maxFractionDigits, max(0, 2 - leading))
        } else {
            places = 0
        }
        var number = UnitsLogic.rounded(scaled, places: places)
        if number.isZero { number = 0 }
        let formatter = UnitsLogic.numberFormatter(locale: locale)
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = places
        return (formatter.string(from: number as NSDecimalNumber) ?? "\(number)") + suffix
    }
}

// MARK: - Deep link

/// tape://open?category=area&unit=plot&amount=1. The widget opens Tape on
/// its conversion; Tape reads it in `.onOpenURL`.
nonisolated struct TapeLink: Equatable, Sendable {
    static let scheme = "tape"
    static let host = "open"

    let category: UnitCategory
    let unitID: String
    let amount: Double

    var unit: TapeUnit { UnitCatalog.unitOrDefault(unitID, in: category) }

    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        components.queryItems = [
            URLQueryItem(name: "category", value: category.rawValue),
            URLQueryItem(name: "unit", value: unitID),
            URLQueryItem(name: "amount", value: "\(UnitsLogic.decimal(amount))"),
        ]
        return components.url!
    }

    init(category: UnitCategory, unitID: String, amount: Double) {
        self.category = category
        self.unitID = unitID
        self.amount = amount
    }

    /// Nil for anything that isn't a Tape link. A missing or unknown unit or
    /// amount falls back to the category's usual one.
    init?(url: URL) {
        guard url.scheme == Self.scheme, url.host() == Self.host,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let category = items.first(where: { $0.name == "category" })?.value.flatMap(UnitCategory.init(rawValue:))
        else { return nil }
        let value = { (name: String) in items.first { $0.name == name }?.value }
        self.category = category
        unitID = UnitCatalog.unitOrDefault(value("unit"), in: category).id
        let posix = Locale(identifier: "en_US_POSIX")
        amount = value("amount").flatMap { UnitsLogic.parseAmount($0, locale: posix) }
            ?? UnitsLogic.parseAmount(category.defaultAmount, locale: posix)
            ?? 1
    }

    /// The amount as the field holds it: "2.5" or "2,5", no grouping, the
    /// true minus.
    func fieldText(locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 6
        let plain = formatter.string(from: UnitsLogic.decimal(amount) as NSDecimalNumber) ?? ""
        return UnitsLogic.sanitizeAmount(plain, allowsNegative: category.allowsNegative, locale: locale)
    }
}
