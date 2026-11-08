//
//  ConversionIntent.swift
//  TapeWidget
//
//  What the user picks when they edit the widget: a category, the unit and
//  amount to convert, and the unit to show the answer in. Left alone it's
//  1 plot in square metres. The unit lists follow the chosen category, and a
//  unit left over from another category falls back to the usual one (see
//  `WidgetConversion.resolve`).
//

import AppIntents
import WidgetKit

struct ConversionIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Conversion"
    static let description = IntentDescription("Pick what the widget converts.")

    @Parameter(title: "Category", default: .area)
    var category: CategoryOption

    @Parameter(title: "From", optionsProvider: FromUnitOptions())
    var fromUnit: UnitEntity?

    @Parameter(title: "Amount", default: 1)
    var amount: Double

    @Parameter(title: "To", optionsProvider: ToUnitOptions())
    var toUnit: UnitEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$amount) \(\.$fromUnit) in \(\.$toUnit)") {
            \.$category
        }
    }
}

// MARK: - Category

enum CategoryOption: String, AppEnum {
    case length, area, weight, volume, temperature, cooking

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static let caseDisplayRepresentations: [CategoryOption: DisplayRepresentation] = [
        .length: "Length",
        .area: "Area",
        .weight: "Weight",
        .volume: "Volume",
        .temperature: "Temperature",
        .cooking: "Cooking",
    ]

    var unitCategory: UnitCategory { UnitCategory(rawValue: rawValue) ?? .area }
}

// MARK: - Units

/// A unit in a category. The id carries both, "volume-ml", because millilitres
/// are in Volume and in Cooking.
struct UnitEntity: AppEntity {
    let id: String
    let name: String
    let symbol: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Unit"
    static let defaultQuery = UnitQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(symbol)")
    }

    var unitID: String { String(id.split(separator: "-", maxSplits: 1).last ?? "") }

    init(_ unit: TapeUnit) {
        id = "\(unit.category.rawValue)-\(unit.id)"
        name = unit.name
        symbol = unit.symbol
    }

    static func all(in category: UnitCategory) -> [UnitEntity] {
        category.units.map(UnitEntity.init)
    }
}

struct UnitQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [UnitEntity] {
        UnitCategory.allCases.flatMap(UnitEntity.all(in:)).filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [UnitEntity] {
        UnitEntity.all(in: .area)
    }
}

/// The units of whichever category is picked, defaulting to its usual one.
struct FromUnitOptions: DynamicOptionsProvider {
    @IntentParameterDependency<ConversionIntent>(\.$category) var intent

    private var category: UnitCategory { intent?.category.unitCategory ?? .area }

    func results() async throws -> [UnitEntity] {
        UnitEntity.all(in: category)
    }

    func defaultResult() async -> UnitEntity? {
        UnitEntity(UnitCatalog.unitOrDefault(nil, in: category))
    }
}

/// The same list; the default is the answer the app lists first for the usual
/// input unit.
struct ToUnitOptions: DynamicOptionsProvider {
    @IntentParameterDependency<ConversionIntent>(\.$category) var intent

    private var category: UnitCategory { intent?.category.unitCategory ?? .area }

    func results() async throws -> [UnitEntity] {
        UnitEntity.all(in: category)
    }

    func defaultResult() async -> UnitEntity? {
        UnitEntity(WidgetConversion.defaultAnswerUnit(for: UnitCatalog.unitOrDefault(nil, in: category)))
    }
}
