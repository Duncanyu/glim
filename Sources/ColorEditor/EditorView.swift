import AppKit
import CoreGraphics
import SwiftUI

@MainActor
struct EditorView: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                VStack(alignment: .leading, spacing: 16) {
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
            .scrollIndicators(.visible)

            footer
        }
        .padding(20)
        .frame(minWidth: 470, idealWidth: 520, minHeight: 560, idealHeight: 680)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "display")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.showsSettings ? "Settings" : "Color controls")
                    .font(.headline)
                Text(model.showsSettings ? "Preferences and display tools" : "Adjust the selected display")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                model.showsSettings.toggle()
            } label: {
                Label(model.showsSettings ? "Controls" : "Settings",
                      systemImage: model.showsSettings ? "slider.horizontal.3" : "gearshape")
            }
            .help(model.showsSettings ? "Back to controls" : "Settings")

            Toggle("On", isOn: $model.enabled)
                .toggleStyle(.switch)
                .accessibilityLabel("Adjustments enabled")
                .help(model.enabled ? "Pause display adjustments" : "Resume display adjustments")
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
            HStack(spacing: 8) {
                ForEach(Preset.allCases) { preset in
                    Button(preset.rawValue) { apply(preset) }
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var toneControls: some View {
        GroupBox("Light and tone") {
            VStack(spacing: 12) {
                slider("Brightness", value: $model.settings.brightness, range: 0.1...1, neutral: 1,
                       hint: "Apparent brightness. Does not change the display backlight.")
                slider("Contrast", value: $model.settings.contrast, range: 0.5...1.5, neutral: 1)
                if model.interfaceMode == .professional {
                    slider("Gamma", value: $model.settings.gamma, range: 0.5...2, neutral: 1,
                           scale: 1, unit: "×")
                }
            }
        }
    }

    private var tintControls: some View {
        GroupBox("Color") {
            VStack(alignment: .leading, spacing: 12) {
                slider("Warmth", value: $model.settings.warmth, range: -1...1, neutral: 0,
                       lowLabel: "Cooler", highLabel: "Warmer")
                if model.interfaceMode == .professional {
                    slider("Green–magenta balance", value: $model.settings.tint,
                           range: -1...1, neutral: 0, lowLabel: "Green", highLabel: "Magenta")
                }

                Divider()
                Text("Tint color")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 8) {
                    ForEach(quickTints.indices, id: \.self) { index in
                        let choice = quickTints[index]
                        Button {
                            tintColor.wrappedValue = choice.color
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(choice.color)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().strokeBorder(.secondary, lineWidth: 0.5))
                                    .accessibilityHidden(true)
                                Text(choice.name)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .accessibilityLabel("Set \(choice.name) tint")
                    }
                }
                .buttonStyle(.bordered)

                ColorPicker("Custom tint color", selection: tintColor, supportsOpacity: false)
                    .accessibilityHint("Choosing a color sets tint strength to 50 percent if it is off.")
                slider("Tint strength", value: $model.settings.tintStrength, range: 0...1, neutral: 0)
            }
        }
    }

    private var channelControls: some View {
        GroupBox("RGB channels") {
            VStack(alignment: .leading, spacing: 12) {
                channelHeading("Highlights", detail: "Gain")
                slider("Red", value: $model.settings.redGain, range: 0.1...1.5,
                       neutral: 1, accessibleName: "Red highlight gain")
                slider("Green", value: $model.settings.greenGain, range: 0.1...1.5,
                       neutral: 1, accessibleName: "Green highlight gain")
                slider("Blue", value: $model.settings.blueGain, range: 0.1...1.5,
                       neutral: 1, accessibleName: "Blue highlight gain")

                Divider()
                channelHeading("Midtones", detail: "Gamma")
                slider("Red", value: $model.settings.redGamma, range: 0.5...2,
                       neutral: 1, scale: 1, unit: "×", accessibleName: "Red midtone gamma")
                slider("Green", value: $model.settings.greenGamma, range: 0.5...2,
                       neutral: 1, scale: 1, unit: "×", accessibleName: "Green midtone gamma")
                slider("Blue", value: $model.settings.blueGamma, range: 0.5...2,
                       neutral: 1, scale: 1, unit: "×", accessibleName: "Blue midtone gamma")

                Divider()
                channelHeading("Shadows", detail: "Lift")
                slider("Red", value: $model.settings.redLift, range: -0.2...0.2,
                       neutral: 0, accessibleName: "Red shadow lift")
                slider("Green", value: $model.settings.greenLift, range: -0.2...0.2,
                       neutral: 0, accessibleName: "Green shadow lift")
                slider("Blue", value: $model.settings.blueLift, range: -0.2...0.2,
                       neutral: 0, accessibleName: "Blue shadow lift")
            }
        }
    }

    private var settingsControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("App location") {
                Picker("Show in", selection: $model.placement) {
                    Text("Dock").tag(AppPlacement.dock)
                    Text("Menu bar").tag(AppPlacement.menuBar)
                }
                .pickerStyle(.segmented)
            }

            GroupBox("Keyboard shortcut") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Toggle adjustments with ⌃⌥⌘C", isOn: $model.hotkeyEnabled)
                        .accessibilityLabel("Enable Control Option Command C to toggle adjustments")
                    if let status = model.hotkeyStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            GroupBox("Displays") {
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
            if !model.showsSettings {
                Button("Reset this display") { model.resetSelected() }
                    .disabled(model.displays.isEmpty)
            }
            Text("Brightness is an apparent adjustment, not the backlight. Display LUT support varies by Mac and display.")
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private var quickTints: [(name: String, color: Color)] {
        [
            ("Amber", Color(red: 1, green: 0.82, blue: 0.56)),
            ("Rose", Color(red: 1, green: 0.63, blue: 0.72)),
            ("Mint", Color(red: 0.66, green: 1, blue: 0.78)),
            ("Blue", Color(red: 0.65, green: 0.82, blue: 1))
        ]
    }

    private func channelHeading(_ title: String, detail: String) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
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

    private func slider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        neutral: Double,
        scale: Double = 100,
        unit: String = "%",
        accessibleName: String? = nil,
        hint: String? = nil,
        lowLabel: String? = nil,
        highLabel: String? = nil
    ) -> some View {
        let name = accessibleName ?? title
        let clamped = Binding(
            get: { value.wrappedValue },
            set: { value.wrappedValue = min(max($0, range.lowerBound), range.upperBound) }
        )
        let displayed = Binding(
            get: { clamped.wrappedValue * scale },
            set: { clamped.wrappedValue = $0 / scale }
        )
        return VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline.weight(.medium))
            HStack(spacing: 8) {
                Slider(value: clamped, in: range, step: 0.01)
                    .controlSize(.large)
                    .accessibilityLabel(name)
                    .accessibilityValue("\(displayed.wrappedValue.formatted(.number.precision(.fractionLength(scale == 1 ? 2 : 0)))) \(unit)")
                    .accessibilityHint(hint ?? "Use arrow keys for fine adjustments.")

                TextField(title, value: displayed,
                          format: .number.precision(.fractionLength(scale == 1 ? 2 : 0)))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                    .accessibilityLabel("\(name) value in \(unit == "%" ? "percent" : "multiples")")
                Text(unit)
                    .foregroundStyle(.secondary)
                    .frame(width: 16, alignment: .leading)
                    .accessibilityHidden(true)

                Button {
                    clamped.wrappedValue = neutral
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .disabled(abs(clamped.wrappedValue - neutral) < 0.0001)
                .help("Reset \(name)")
                .accessibilityLabel("Reset \(name)")
            }
            if let lowLabel, let highLabel {
                HStack {
                    Text(lowLabel)
                    Spacer()
                    Text(highLabel)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.trailing, 112)
                .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 2)
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
