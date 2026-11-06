//
//  ConverterView.swift
//  Tape
//
//  The one screen. Type a number, pick its unit, and every other unit in the
//  category is listed below. Tap a row to copy it.
//

import SwiftUI
import UIKit

struct ConverterView: View {
    let settings: AppSettings
    private let defaults: UserDefaults

    @State private var category: UnitCategory
    @State private var unit: TapeUnit
    @State private var amountText: String
    @State private var showSettings = LaunchOptions.openSettings
    @State private var toast: Toast?
    @State private var copyTick = 0
    @State private var selectionTick = 0
    @FocusState private var amountFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 48

    init(settings: AppSettings, defaults: UserDefaults = .standard) {
        self.settings = settings
        self.defaults = defaults
        let category = LaunchOptions.category ?? TapePersistence.category(from: defaults)
        _category = State(initialValue: category)
        _unit = State(initialValue: LaunchOptions.unitID.map { UnitCatalog.unitOrDefault($0, in: category) }
            ?? TapePersistence.unit(for: category, from: defaults))
        _amountText = State(initialValue: LaunchOptions.amount ?? TapePersistence.amount(for: category, from: defaults))
    }

    // MARK: Derived values

    private var amount: Double { UnitsLogic.parseAmount(amountText) ?? 0 }

    private var rows: [ResultRow] {
        UnitsLogic.rows(for: amount, from: unit, plot: settings.plot, preference: settings.decimals)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
                header
                categoryChips
                inputCard
                resultsCard
                if category == .area { plotNote }
            }
            .padding(.horizontal, Tokens.Spacing.lg)
            .padding(.top, Tokens.Spacing.sm)
            .padding(.bottom, Tokens.Spacing.xxl * 2)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .overlay(alignment: .bottom) { toastView }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { amountFocused = false }
            }
        }
        .sensoryFeedback(trigger: copyTick) { _, _ in
            settings.haptics ? .impact(weight: .light) : nil
        }
        .sensoryFeedback(trigger: selectionTick) { _, _ in
            settings.haptics ? .selection : nil
        }
        .onChange(of: amountText) { _, newValue in
            let clean = UnitsLogic.sanitizeAmount(newValue, allowsNegative: category.allowsNegative)
            if clean != newValue {
                amountText = clean
            } else {
                TapePersistence.save(amount: clean, for: category, to: defaults)
            }
        }
        .onAppear {
            if LaunchOptions.demoToast, let first = rows.first {
                toast = Toast(text: first.copyText, sticky: true)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Tape")
                .font(Theme.display(.largeTitle).weight(.heavy))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Tokens.Spacing.lg)
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .frame(minWidth: Tokens.Layout.minTapTarget, minHeight: Tokens.Layout.minTapTarget)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(.primary)
            .accessibilityLabel("Settings")
        }
    }

    // MARK: Categories

    private var categoryChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                GlassEffectContainer(spacing: Tokens.Spacing.sm) {
                    HStack(spacing: Tokens.Spacing.sm) {
                        ForEach(UnitCategory.allCases) { item in
                            chip(item).id(item)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            // Opening on Temperature or Cooking shouldn't hide the active chip off the edge.
            .onAppear { proxy.scrollTo(category, anchor: .center) }
            .onChange(of: category) { _, item in
                withAnimation(reduceMotion ? nil : Tokens.Motion.quick) {
                    proxy.scrollTo(item, anchor: .center)
                }
            }
        }
    }

    private func chip(_ item: UnitCategory) -> some View {
        let selected = item == category
        return Button {
            select(item)
        } label: {
            Text(item.title)
                .font(Theme.display(.subheadline).weight(.semibold))
                .foregroundStyle(selected ? Theme.chipText : .primary)
                .padding(.horizontal, Tokens.Spacing.lg)
                .frame(minHeight: Tokens.Layout.minTapTarget - Tokens.Spacing.sm)
                .background {
                    if selected { Capsule().fill(Theme.chipFill) }
                }
                .glassEffect(selected ? .identity : .regular.interactive(), in: .capsule)
                .frame(minHeight: Tokens.Layout.minTapTarget)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Input

    private var inputCard: some View {
        card {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                HStack(spacing: Tokens.Spacing.md) {
                    unitMenu
                    Text(unitCaption)
                        .font(Tokens.Typography.text(.subheadline))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityHidden(true)
                }
                HStack(alignment: .center, spacing: Tokens.Spacing.md) {
                    TextField("0", text: $amountText)
                        .font(Theme.amount(size: amountSize))
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                        .lineLimit(1)
                        .accessibilityLabel("Amount in \(unit.name.lowercased())")
                    if category.allowsNegative {
                        Button {
                            amountText = UnitsLogic.toggleSign(amountText)
                        } label: {
                            Image(systemName: "plus.forwardslash.minus")
                                .font(.title3.weight(.semibold))
                                .frame(width: Tokens.Layout.minTapTarget, height: Tokens.Layout.minTapTarget)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .tint(.primary)
                        .accessibilityLabel("Make negative or positive")
                    }
                }
            }
        }
        .contentShape(.rect)
        .onTapGesture { amountFocused = true }
    }

    /// "Square metres", or "Plots · 60 × 120 ft" so the plot's size is never a guess.
    private var unitCaption: String {
        unit.id == "plot" ? "Plots · \(UnitsLogic.plotDimensions(settings.plot))" : unit.name
    }

    private var unitMenu: some View {
        Menu {
            Picker("Unit", selection: unitBinding) {
                ForEach(category.units) { item in
                    Text("\(item.name) (\(item.symbol))").tag(item)
                }
            }
        } label: {
            HStack(spacing: Tokens.Spacing.sm) {
                Text(unit.symbol)
                    .font(Theme.display(.title3).weight(.semibold))
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Tokens.Spacing.md + Tokens.Spacing.xs)
            .frame(minHeight: Tokens.Layout.minTapTarget)
            .background(.fill.tertiary, in: Capsule())
            .contentShape(Capsule())
        }
        .tint(.primary)
        .accessibilityLabel("Unit: \(unit.name)")
        .accessibilityHint("Changes the unit you're typing in")
    }

    private var unitBinding: Binding<TapeUnit> {
        Binding(get: { unit }, set: { use($0) })
    }

    // MARK: Results

    private var resultsCard: some View {
        let rows = rows
        let symbolSlots = Array(Set(rows.map(\.symbol))).sorted()
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Divider().padding(.leading, Tokens.Spacing.lg)
                }
                resultRow(row, symbolSlots: symbolSlots)
            }
        }
        .padding(.vertical, Tokens.Spacing.xs)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: Tokens.Radius.lg))
    }

    /// `symbolSlots` holds every symbol on screen, so each row's symbol column is
    /// as wide as the widest and the numbers line up on their right edge.
    private func resultRow(_ row: ResultRow, symbolSlots: [String]) -> some View {
        Button {
            copy(row)
        } label: {
            ListRow(title: row.name) {
                EmptyView()
            } trailing: {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.xs + Tokens.Spacing.xxs) {
                    Text(row.value)
                        .font(Tokens.Typography.tabular(.body).weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(reduceMotion ? .identity : .numericText())
                    ZStack(alignment: .leading) {
                        ForEach(symbolSlots, id: \.self) { Text($0).hidden() }
                        Text(row.symbol)
                    }
                    .font(Tokens.Typography.text(.subheadline))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Tokens.Spacing.lg)
        }
        .buttonStyle(RowPressStyle())
        .accessibilityLabel("\(row.name), \(row.copyText)")
        .accessibilityHint("Copies the value")
        .contextMenu {
            Button("Copy \(row.copyText)", systemImage: "doc.on.doc") { copy(row) }
            if let target = UnitCatalog.unit(row.id, in: category) {
                Button("Type in \(target.name.lowercased())", systemImage: "arrow.up") { use(target) }
            }
        }
    }

    // MARK: Plot note

    private var plotNote: some View {
        Button {
            showSettings = true
        } label: {
            Badge(text: "1 plot = \(UnitsLogic.plotSummary(settings.plot))", tone: .accent, systemImage: "square.dashed")
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens settings to change the plot size")
    }

    // MARK: Toast

    @ViewBuilder private var toastView: some View {
        ZStack {
            if let toast {
                Label {
                    Text("Copied \(toast.text)")
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                }
                    .font(Theme.display(.subheadline).weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, Tokens.Spacing.lg)
                    .padding(.vertical, Tokens.Spacing.md)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, Tokens.Spacing.sm)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 12)),
                        removal: .opacity.combined(with: .offset(y: 6))
                    ))
                    .id(toast.id)
                    .accessibilityAddTraits(.isStaticText)
                    .task(id: toast.id) {
                        guard !toast.sticky else { return }
                        try? await Task.sleep(for: .seconds(1.6))
                        hideToast(toast.id)
                    }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Actions

    private func select(_ item: UnitCategory) {
        guard item != category else { return }
        withAnimation(reduceMotion ? nil : Tokens.Motion.quick) {
            category = item
        }
        unit = TapePersistence.unit(for: item, from: defaults)
        amountText = TapePersistence.amount(for: item, from: defaults)
        TapePersistence.save(category: item, to: defaults)
        selectionTick += 1
    }

    /// Makes `target` the unit being typed in, carrying the value across so
    /// 668.9 m² becomes 1 plot rather than 668.9 plots.
    private func use(_ target: TapeUnit) {
        guard target != unit else { return }
        let converted = UnitsLogic.convert(amount, from: unit, to: target, plot: settings.plot)
        unit = target
        if UnitsLogic.parseAmount(amountText) != nil {
            let places = UnitsLogic.fractionDigits(for: converted, unit: target, preference: .auto).max
            amountText = UnitsLogic.sanitizeAmount(
                plainNumber(converted, places: places),
                allowsNegative: category.allowsNegative
            )
        }
        TapePersistence.save(unit: target, to: defaults)
        selectionTick += 1
    }

    /// A rounded value as the field holds it: no grouping, locale decimal mark.
    private func plainNumber(_ value: Double, places: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = places
        return formatter.string(from: UnitsLogic.rounded(value, places: places) as NSDecimalNumber) ?? ""
    }

    private func copy(_ row: ResultRow) {
        UIPasteboard.general.string = row.copyText
        copyTick += 1
        let next = Toast(text: row.copyText)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
            toast = next
        }
        UIAccessibility.post(notification: .announcement, argument: "Copied \(row.copyText)")
    }

    private func hideToast(_ id: UUID) {
        guard toast?.id == id else { return }
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.18)) {
            toast = nil
        }
    }

    // MARK: Card

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, Tokens.Spacing.lg)
            .padding(.vertical, Tokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: Tokens.Radius.lg))
    }
}

private struct Toast: Equatable {
    let id = UUID()
    let text: String
    var sticky = false
}

/// A row that darkens while pressed, like a table cell. No scale: rows are
/// tapped often and sit edge to edge.
private struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(.systemFill) : .clear)
    }
}

#Preview {
    ConverterView(settings: AppSettings())
}
