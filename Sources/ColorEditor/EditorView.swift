import AppKit
import CoreGraphics
import SwiftUI

@MainActor
struct EditorView: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            displayPicker

            if !model.showsSettings {
                Picker("Control mode", selection: $model.interfaceMode) {
                    Text("Beginner").tag(InterfaceMode.beginner)
                    Text("Professional").tag(InterfaceMode.professional)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if model.showsSettings {
                        settingsControls
                    } else if !model.displays.isEmpty {
                        presets
                        toneControls
                        tintControls
                        if model.interfaceMode == .professional {
                            channelControls
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            footer
        }
        .padding(18)
        .frame(minWidth: 390, idealWidth: 440, minHeight: 500, idealHeight: 620)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "display")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Color controls")
                    .font(.headline)
                Text("Adjust the selected display")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                model.showsSettings.toggle()
            } label: {
                Image(systemName: model.showsSettings ? "slider.horizontal.3" : "gearshape")
            }
            .help(model.showsSettings ? "Back to controls" : "Settings")
            .accessibilityLabel(model.showsSettings ? "Back to controls" : "Settings")

            Toggle("Adjustments enabled", isOn: $model.enabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private var displayPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.displays.isEmpty {
                HStack {
                    Label("No displays available", systemImage: "display.trianglebadge.exclamationmark")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh") { model.refreshDisplays() }
                }
            } else {
                Picker("Display", selection: Binding(
                    get: { model.selectedDisplayID },
                    set: { model.selectDisplay($0) }
                )) {
                    ForEach(model.displays) { display in
                        Text(display.isMain ? "\(display.name) · Main" : display.name)
                            .tag(display.id)
                    }
                }
                .pickerStyle(.menu)
            }

            if let error = model.errorMessage, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Label(model.enabled ? "Adjustments on" : "Adjustments paused",
                      systemImage: model.enabled ? "checkmark.circle.fill" : "pause.circle.fill")
                    .font(.caption)
                    .foregroundStyle(model.enabled ? Color.green : Color.secondary)
            }
        }
    }

    private var presets: some View {
        GroupBox("Quick looks") {
            HStack(spacing: 6) {
                ForEach(Preset.allCases) { preset in
                    Button(preset.rawValue) { apply(preset) }
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var toneControls: some View {
        GroupBox("Tone") {
            VStack(spacing: 9) {
                slider("Dimming", value: $model.settings.brightness, range: 0.1...1)
                slider("Contrast", value: $model.settings.contrast, range: 0.5...1.5)
                if model.interfaceMode == .professional {
                    slider("Gamma", value: $model.settings.gamma, range: 0.5...2)
                }
                slider("Warmth", value: $model.settings.warmth, range: -1...1)
                if model.interfaceMode == .professional {
                    slider("Tint balance", value: $model.settings.tint, range: -1...1)
                }
            }
        }
    }

    private var tintControls: some View {
        GroupBox("Color tint") {
            VStack(spacing: 9) {
                ColorPicker("Tint color", selection: tintColor, supportsOpacity: false)
                slider("Strength", value: $model.settings.tintStrength, range: 0...1)
            }
        }
    }

    private var channelControls: some View {
        GroupBox("RGB channels") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Gain · highlights")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                slider("Red", value: $model.settings.redGain, range: 0.1...1.5)
                slider("Green", value: $model.settings.greenGain, range: 0.1...1.5)
                slider("Blue", value: $model.settings.blueGain, range: 0.1...1.5)

                Divider()
                Text("Gamma · midtones")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                slider("Red", value: $model.settings.redGamma, range: 0.5...2)
                slider("Green", value: $model.settings.greenGamma, range: 0.5...2)
                slider("Blue", value: $model.settings.blueGamma, range: 0.5...2)

                Divider()
                Text("Lift · shadows")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                slider("Red", value: $model.settings.redLift, range: -0.2...0.2)
                slider("Green", value: $model.settings.greenLift, range: -0.2...0.2)
                slider("Blue", value: $model.settings.blueLift, range: -0.2...0.2)
            }
        }
    }

    private var settingsControls: some View {
        GroupBox("Settings") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Show in", selection: $model.placement) {
                    Text("Dock").tag(AppPlacement.dock)
                    Text("Menu bar").tag(AppPlacement.menuBar)
                }
                .pickerStyle(.segmented)

                HStack {
                    Button("Refresh displays") { model.refreshDisplays() }
                    Spacer()
                    Button("Reset all displays") { model.resetAll() }
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Reset this display") { model.resetSelected() }
                    .disabled(model.displays.isEmpty)
                Spacer()
                Text(model.showsSettings ? "Settings" : model.interfaceMode == .beginner ? "Simple controls" : "Per-channel controls")
                    .foregroundStyle(.secondary)
            }
            Text("Brightness is an apparent adjustment, not the backlight. Display LUT support varies by Mac and display.")
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private var tintColor: Binding<Color> {
        Binding(
            get: {
                Color(red: model.settings.tintRed,
                      green: model.settings.tintGreen,
                      blue: model.settings.tintBlue)
            },
            set: { value in
                guard let color = NSColor(value).usingColorSpace(.sRGB) else { return }
                var settings = model.settings
                settings.tintRed = min(max(Double(color.redComponent), 0), 1)
                settings.tintGreen = min(max(Double(color.greenComponent), 0), 1)
                settings.tintBlue = min(max(Double(color.blueComponent), 0), 1)
                if settings.tintStrength == 0 { settings.tintStrength = 0.5 }
                model.settings = settings
            }
        )
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        let clamped = Binding(
            get: { value.wrappedValue },
            set: { value.wrappedValue = min(max($0, range.lowerBound), range.upperBound) }
        )
        return HStack(spacing: 8) {
            Text(title)
                .frame(width: 88, alignment: .leading)
            Slider(value: clamped, in: range)
                .accessibilityLabel(title)
            TextField(title, value: clamped, format: .number.precision(.fractionLength(2)))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 54)
                .accessibilityLabel("\(title) value")
        }
    }

    private func apply(_ preset: Preset) {
        var settings = DisplaySettings()
        switch preset {
        case .neutral:
            break
        case .warm:
            settings.warmth = 0.35
        case .cool:
            settings.warmth = -0.35
        case .contrast:
            settings.contrast = 1.15
        }
        model.settings = settings
    }

    private enum Preset: String, CaseIterable, Identifiable {
        case neutral = "Neutral"
        case warm = "Warm"
        case cool = "Cool"
        case contrast = "Contrast"

        var id: Self { self }
    }
}
