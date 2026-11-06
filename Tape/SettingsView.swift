//
//  SettingsView.swift
//  Tape
//
//  Native Form, which picks up iOS 26 Liquid Glass chrome on its own.
//

import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                plotSection
                if settings.plot.preset == .custom { customPlotSection }
                displaySection
                feelSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Plot

    private var plotSection: some View {
        Section {
            Picker("Plot size", selection: $settings.plot.preset) {
                ForEach(PlotPreset.allCases) { preset in
                    presetLabel(preset).tag(preset)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Plot size")
        } footer: {
            Text("A plot in Lagos and Abuja is usually 60 × 120 ft, which is 668.9 m². The 648 m² you often see online is the metric 18 × 36 m plot.")
        }
    }

    private func presetLabel(_ preset: PlotPreset) -> some View {
        var plot = settings.plot
        plot.preset = preset
        return VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
            Text(title(for: preset))
            Text(subtitle(for: preset, plot: plot))
                .font(Tokens.Typography.text(.footnote))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func title(for preset: PlotPreset) -> String {
        guard preset != .custom else { return "Custom" }
        var plot = PlotSize()
        plot.preset = preset
        return UnitsLogic.plotDimensions(plot)
    }

    private func subtitle(for preset: PlotPreset, plot: PlotSize) -> String {
        let area = UnitsLogic.format(plot.squareMetres, unit: UnitCatalog.unit("m2", in: .area)!)
        return switch preset {
        case .feet60x120: "Lagos and Abuja · \(area)"
        case .feet50x100: "Smaller plots · \(area)"
        case .metres18x36: "Metric plot · \(area)"
        case .custom: plot.isValid ? "\(UnitsLogic.plotDimensions(plot)) · \(area)" : "Enter a width and length"
        }
    }

    private var customPlotSection: some View {
        Section("Custom plot") {
            LabeledContent("Width") {
                TextField("Width", value: $settings.plot.customWidth, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
            }
            LabeledContent("Length") {
                TextField("Length", value: $settings.plot.customLength, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
            }
            Picker("Measured in", selection: $settings.plot.customUnit) {
                Text("Feet").tag(PlotSideUnit.feet)
                Text("Metres").tag(PlotSideUnit.metres)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: Display

    private var displaySection: some View {
        Section {
            Picker("Decimal places", selection: $settings.decimals) {
                ForEach(DecimalPreference.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Decimal places")
        } header: {
            Text("Decimal places")
        } footer: {
            Text("Auto keeps four significant figures without rounding away whole numbers: 668.9 m², 7,200 ft², 0.1653 ac.")
        }
    }

    // MARK: Feel

    private var feelSection: some View {
        Section("Feel") {
            Toggle("Haptics", isOn: $settings.haptics)
                .tint(Theme.accent)
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section {
            LabeledContent("Version") {
                Text(appVersion).foregroundStyle(.secondary)
            }
            LabeledContent("Made by") {
                Text("DevAkintola").foregroundStyle(.secondary)
            }
        } header: {
            Text("About")
        } footer: {
            Text("Tape works entirely offline. It has no network code at all.")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
