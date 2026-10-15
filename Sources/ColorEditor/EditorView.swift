import AppKit
import CoreGraphics
import SwiftUI

private struct GlimGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            configuration.label.font(.headline)
            configuration.content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(Color.primary.opacity(0.06))
        }
    }
}

@MainActor
struct EditorView: View {
    @ObservedObject var model: EditorModel
    @State private var page = 0

    private let surface = Color.black.opacity(0.045)
    private let accent = Color(red: 0.08, green: 0.48, blue: 0.98)

    var body: some View {
        TabView(selection: $page) {
            ScrollView { dashboard }
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
                .tag(0)
            ScrollView { advanced }
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
                .tag(1)
            ScrollView { general }
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(2)
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(accent)
        .groupBoxStyle(GlimGroupBoxStyle())
        .preferredColorScheme(.light)
        .onAppear { if model.showsSettings { page = 2 } }
        .onChange(of: model.showsSettings) { _, settings in if settings { page = 2 } }
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Glim color").font(.largeTitle.bold())
                Spacer()
                Toggle("On", isOn: $model.enabled)
                    .accessibilityLabel("Adjustments enabled")
            }
            displayPicker
                .padding(14)
                .background(surface, in: RoundedRectangle(cornerRadius: 14))
            if !model.displays.isEmpty {
                presets
                HStack(alignment: .top, spacing: 14) {
                    toneControls
                    tintControls
                }
                visualReference
                footer
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var advanced: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Advanced color").font(.largeTitle.bold())
            displayPicker
                .padding(14)
                .background(surface, in: RoundedRectangle(cornerRadius: 14))
            if !model.displays.isEmpty {
                HStack(alignment: .top, spacing: 14) {
                    channelControls
                    VStack(spacing: 14) {
                        GroupBox("Color balance") {
                            slider("Green–magenta balance", value: $model.settings.tint,
                                   range: -1...1, neutral: 0, lowLabel: "Green", highLabel: "Magenta")
                        }
                        visualReference
                    }
                }
                footer
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("General").font(.largeTitle.bold())
            settingsControls
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 12) {
                Label("Display", systemImage: "display")
                    .font(.headline)
                Spacer()
                if model.displays.isEmpty {
                    Text("No displays available").foregroundStyle(.secondary)
                    Button("Refresh") { model.refreshDisplays() }
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
                    .labelsHidden()
                }
            }
            if let error = model.errorMessage, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Label(model.enabled ? "Adjustments on" : "Adjustments paused",
                      systemImage: model.enabled ? "checkmark.circle.fill" : "pause.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    private var visualReference: some View {
        let input: [CGGammaValue] = [0, 0.25, 0.5, 0.75, 1]
        let output = GammaTable(red: input, green: input, blue: input)
            .adjusted(with: model.settings)

        return GroupBox(model.enabled ? "Color reference" : "Preview when enabled") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tone levels")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(input.indices, id: \.self) { index in
                        referenceSwatch(
                            red: output.red[index], green: output.green[index], blue: output.blue[index],
                            label: "\(Int(input[index] * 100))% input"
                        )
                    }
                }
                Text("50% input → R \(percent(output.red[2])) · G \(percent(output.green[2])) · B \(percent(output.blue[2]))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Text("Color channels")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    referenceSwatch(
                        red: output.red[4], green: output.green[0], blue: output.blue[0],
                        label: "Red"
                    )
                    referenceSwatch(
                        red: output.red[0], green: output.green[4], blue: output.blue[0],
                        label: "Green"
                    )
                    referenceSwatch(
                        red: output.red[0], green: output.green[0], blue: output.blue[4],
                        label: "Blue"
                    )
                }
                Text(model.enabled
                     ? "Illustrative preview based on a neutral curve; the display profile may differ."
                     : "Adjustments are paused. This previews the saved look when enabled.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func referenceSwatch(red: CGGammaValue, green: CGGammaValue, blue: CGGammaValue, label: String) -> some View {
        let output = "R \(percent(red)), G \(percent(green)), B \(percent(blue))"
        return VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(red: Double(red), green: Double(green), blue: Double(blue)))
                .frame(height: 28)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.2), lineWidth: 1))
                .accessibilityHidden(true)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .help("\(label): estimated output \(output)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), estimated output \(output)")
    }

    private func percent(_ value: CGGammaValue) -> String {
        "\(Int((Double(value) * 100).rounded()))%"
    }

    private var toneControls: some View {
        GroupBox("Light and tone") {
            VStack(spacing: 12) {
                slider("Brightness", value: $model.settings.brightness, range: 0.1...1, neutral: 1,
                       hint: "Apparent brightness. Does not change the display backlight.")
                slider("Contrast", value: $model.settings.contrast, range: 0.5...1.5, neutral: 1)
                slider("Gamma", value: $model.settings.gamma, range: 0.5...3, neutral: 1,
                       scale: 1, unit: "×", accessibleName: "Gamma shadow boost",
                       hint: "Raise gamma to reveal near-black detail while preserving white.",
                       lowLabel: "Darker", highLabel: "Brighter")
            }
        }
    }

    private var tintControls: some View {
        GroupBox("Color") {
            VStack(alignment: .leading, spacing: 12) {
                slider("Warmth", value: $model.settings.warmth, range: -1...1, neutral: 0,
                       lowLabel: "Cooler", highLabel: "Warmer")
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

            GroupBox("Menu bar controls") {
                Picker("Control mode", selection: $model.interfaceMode) {
                    Text("Beginner").tag(InterfaceMode.beginner)
                    Text("Professional").tag(InterfaceMode.professional)
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
            Button("Reset this display") { model.resetSelected() }
                .disabled(model.displays.isEmpty)
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
        let precision = scale == 1 ? 2 : 0
        let measure: (Double) -> String = { number in
            "\((number * scale).formatted(.number.precision(.fractionLength(precision))))\(unit)"
        }
        let clamped = Binding(
            get: { value.wrappedValue },
            set: { value.wrappedValue = min(max($0, range.lowerBound), range.upperBound) }
        )
        let displayed = Binding(
            get: { clamped.wrappedValue * scale },
            set: { clamped.wrappedValue = $0 / scale }
        )
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("Default \(measure(neutral))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Slider(value: clamped, in: range, step: 0.01)
                    .controlSize(.large)
                    .accessibilityLabel(name)
                    .accessibilityValue(measure(clamped.wrappedValue))
                    .accessibilityHint("\(hint ?? "Use arrow keys for fine adjustments.") Range \(measure(range.lowerBound)) to \(measure(range.upperBound)); default \(measure(neutral)).")

                TextField(title, value: displayed,
                          format: .number.precision(.fractionLength(precision)))
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
            HStack {
                Text("\(lowLabel ?? "Min") \(measure(range.lowerBound))")
                Spacer()
                Text("\(highLabel ?? "Max") \(measure(range.upperBound))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.trailing, 112)
            .accessibilityHidden(true)
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
