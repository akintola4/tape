//
//  ConverterView.swift
//  Tape
//
//  The one screen. Type a number and pick its unit; a drawing pictures it,
//  and every other unit in the category is listed below, most useful first.
//  Tap a row to copy it.
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
    /// Wide enough for "US gal", so every value ends at the same x.
    @ScaledMetric(relativeTo: .subheadline) private var symbolSlot: CGFloat = 50

    init(settings: AppSettings, defaults: UserDefaults = TapeShared.defaults) {
        self.settings = settings
        self.defaults = defaults
        let category = LaunchOptions.category ?? TapePersistence.category(from: defaults)
        _category = State(initialValue: category)
        _unit = State(initialValue: LaunchOptions.unitID.map { UnitCatalog.unitOrDefault($0, in: category) }
            ?? TapePersistence.unit(for: category, from: defaults))
        // Sanitized so an amount saved or passed with a hyphen shows the true minus.
        _amountText = State(initialValue: UnitsLogic.sanitizeAmount(
            LaunchOptions.amount ?? TapePersistence.amount(for: category, from: defaults),
            allowsNegative: category.allowsNegative
        ))
    }

    // MARK: Derived values

    private var amount: Double { UnitsLogic.parseAmount(amountText) ?? 0 }

    private var rows: [ResultRow] {
        UnitsLogic.rows(for: amount, from: unit, plot: settings.plot, preference: settings.decimals)
    }

    private var picture: Picture {
        PictureLogic.picture(for: amount, unit: unit, plot: settings.plot)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                header
                categoryChips
                inputCard
                card { PictureCard(picture: picture) }
                resultsCard
            }
            .padding(.horizontal, Tokens.Spacing.lg)
            .padding(.top, Tokens.Spacing.sm)
            .padding(.bottom, Tokens.Spacing.xxl * 2)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.screenBackground)
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
        .task {
            guard let keys = LaunchOptions.demoTyping else { return }
            try? await Task.sleep(for: .seconds(2.5))
            amountFocused = true
            amountText = ""
            for key in keys {
                try? await Task.sleep(for: .milliseconds(700))
                if key == "<" { amountText = String(amountText.dropLast()) } else { amountText.append(key) }
            }
        }
        .onOpenURL { url in
            if let link = TapeLink(url: url) { open(link) }
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
                    .foregroundStyle(.primary)
                    .frame(width: Tokens.Layout.minTapTarget, height: Tokens.Layout.minTapTarget)
                    .background(Color(.secondarySystemFill), in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Settings")
        }
    }

    // MARK: Categories

    private var categoryChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: Tokens.Spacing.sm) {
                    ForEach(UnitCategory.allCases) { item in
                        chip(item).id(item)
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
                .background(selected ? Theme.chipFill : Color(.secondarySystemFill), in: .capsule)
                .frame(minHeight: Tokens.Layout.minTapTarget)
                .contentShape(.capsule)
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Input

    private var inputCard: some View {
        card {
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
                            .foregroundStyle(.primary)
                            .frame(width: Tokens.Layout.minTapTarget, height: Tokens.Layout.minTapTarget)
                            .background(Color(.secondarySystemFill), in: .circle)
                            .contentShape(.circle)
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("Make negative or positive")
                }
                unitMenu
            }
        }
        .contentShape(.rect)
        .onTapGesture { amountFocused = true }
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
            .background(Color(.secondarySystemFill), in: Capsule())
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
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Divider() }
                resultRow(row)
            }
        }
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: Tokens.Radius.lg))
    }

    /// Name on the left; the value right-aligned against a fixed-width symbol
    /// slot, so every value ends at the same x whether the unit is "m²" or "plots".
    private func resultRow(_ row: ResultRow) -> some View {
        Button {
            copy(row)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(row.name)
                    .font(Tokens.Typography.text(.body))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(row.value)
                    .font(Tokens.Typography.tabular(.body).weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                Text(row.symbol)
                    .font(Tokens.Typography.text(.subheadline))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.leading, Tokens.Spacing.sm)
                    .frame(width: symbolSlot, alignment: .leading)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Tokens.Spacing.lg)
            .padding(.vertical, Tokens.Spacing.md)
            .frame(minHeight: Tokens.Layout.minTapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(RowPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.name), \(row.copyText)")
        .accessibilityHint("Copies the value")
        .contextMenu {
            Button("Copy \(row.copyText)", systemImage: "doc.on.doc") { copy(row) }
            if let target = UnitCatalog.unit(row.id, in: category) {
                Button("Type in \(target.name.lowercased())", systemImage: "arrow.up") { use(target) }
            }
        }
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

    /// A tap on the widget: its category, unit and amount, kept as if typed.
    private func open(_ link: TapeLink) {
        withAnimation(reduceMotion ? nil : Tokens.Motion.quick) {
            category = link.category
        }
        unit = link.unit
        amountText = link.fieldText()
        showSettings = false
        TapePersistence.save(category: link.category, to: defaults)
        TapePersistence.save(unit: link.unit, to: defaults)
        TapePersistence.save(amount: amountText, for: link.category, to: defaults)
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
            .background(Theme.cardBackground, in: .rect(cornerRadius: Tokens.Radius.lg))
    }
}

private struct Toast: Equatable {
    let id = UUID()
    let text: String
    var sticky = false
}

/// The 0.96 press for the gear, the chips and the sign key.
private struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
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
