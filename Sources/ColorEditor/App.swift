import AppKit
import CoreGraphics
import SwiftUI

@main
enum ColorEditorMain {
    @MainActor private static let delegate = AppDelegate()

    @MainActor static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = EditorModel()
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var hotkeyController: HotkeyController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.onEnabledChange = { [weak self] enabled in self?.updateStatusItem(enabled: enabled) }
        model.onPlacementChange = { [weak self] placement in self?.updatePlacement(placement) }
        model.onHotkeyPreferenceChange = { [weak self] enabled in self?.updateHotkey(enabled: enabled) }
        hotkeyController = HotkeyController { [weak self] in self?.model.enabled.toggle() }

        installAppMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(displaysChanged), name: NSWorkspace.didWakeNotification, object: nil)
        updatePlacement(model.placement)
        updateStatusItem(enabled: model.enabled)
        updateHotkey(enabled: model.hotkeyEnabled)
        if model.placement == .dock { openEditor() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if model.placement == .menuBar { showPopover() }
            else { openEditor() }
        }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyController?.stop()
        model.restoreDisplays()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let title = model.enabled ? "Pause Adjustments" : "Resume Adjustments"
        menu.item(withTag: 1)?.title = model.hotkeyEnabled && model.hotkeyStatus == nil ? "\(title)  ⌃⌥⌘C" : title
    }

    @objc private func displaysChanged() { model.refreshDisplays() }

    @objc private func openEditor() {
        popover?.close()
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 680),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Glim"
            window.contentMinSize = NSSize(width: 470, height: 560)
            window.contentView = NSHostingView(rootView: EditorView(model: model))
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSettings() {
        model.showsSettings = true
        if model.placement == .menuBar { showPopover() }
        else { openEditor() }
    }

    @objc private func togglePopover() {
        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            model.showsSettings = false
            showPopover()
        }
    }

    @objc private func toggleAdjustments() { model.enabled.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func updatePlacement(_ placement: AppPlacement) {
        switch placement {
        case .menuBar:
            if statusItem == nil { installStatusItem() }
            NSApp.setActivationPolicy(.accessory)
            if window?.isVisible == true {
                window?.orderOut(nil)
                model.showsSettings = false
                showPopover()
            }
        case .dock:
            let movedFromMenuBar = statusItem != nil
            popover?.close()
            NSApp.setActivationPolicy(.regular)
            if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
            statusItem = nil
            if movedFromMenuBar { openEditor() }
        }
    }

    private func updateHotkey(enabled: Bool) {
        guard enabled else {
            hotkeyController?.stop()
            model.hotkeyStatus = nil
            return
        }
        guard let hotkeyController else { return }
        let status = hotkeyController.start()
        model.hotkeyStatus = status == noErr ? nil : "Shortcut unavailable (error \(status))."
    }

    private func updateStatusItem(enabled: Bool) {
        let statusName = enabled ? "glim-active" : "glim-deactivated"
        if let image = NSImage(named: NSImage.Name(statusName)) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            statusItem?.button?.image = image
        }
        statusItem?.button?.toolTip = enabled ? "Glim: adjustments on" : "Glim: adjustments paused"
        statusItem?.button?.setAccessibilityLabel(enabled ? "Glim adjustments on" : "Glim adjustments paused")

        let dockName = enabled ? "Glim" : "Glim-Deactivated"
        if let url = Bundle.main.url(forResource: dockName, withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = image
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
        updateStatusItem(enabled: model.enabled)
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        if popover == nil {
            let popover = NSPopover()
            popover.behavior = .transient
            popover.contentSize = NSSize(width: 340, height: 530)
            popover.contentViewController = NSHostingController(rootView: MenuBarControlsView(
                model: model,
                openFullEditor: { [weak self] in self?.openEditor() },
                quit: { [weak self] in self?.quit() }
            ))
            self.popover = popover
        }
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover?.contentViewController?.view.window?.makeKey()
    }

    private func installAppMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem(title: "Glim", action: nil, keyEquivalent: "")
        let appMenu = NSMenu()
        appMenu.delegate = self
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let settings = menuItem("Settings…", action: #selector(openSettings))
        settings.keyEquivalent = ","
        settings.keyEquivalentModifierMask = [.command]
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        let toggle = menuItem("Pause Adjustments", action: #selector(toggleAdjustments))
        toggle.tag = 1
        appMenu.addItem(toggle)
        appMenu.addItem(.separator())
        let quit = menuItem("Quit Glim", action: #selector(quit))
        quit.keyEquivalent = "q"
        quit.keyEquivalentModifierMask = [.command]
        appMenu.addItem(quit)

        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        for (title, selector, key, modifiers) in [
            ("Undo", "undo:", "z", NSEvent.ModifierFlags.command),
            ("Redo", "redo:", "z", [.command, .shift]),
            ("Cut", "cut:", "x", .command),
            ("Copy", "copy:", "c", .command),
            ("Paste", "paste:", "v", .command),
            ("Select All", "selectAll:", "a", .command)
        ] {
            let item = NSMenuItem(title: title, action: Selector(selector), keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            editMenu.addItem(item)
        }
        NSApp.mainMenu = mainMenu
    }

    private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }
}

@MainActor
private struct MenuBarControlsView: View {
    @ObservedObject var model: EditorModel
    let openFullEditor: () -> Void
    let quit: () -> Void

    @State private var region = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.showsSettings ? "Glim Settings" : "Glim controls")
                    .font(.headline)
                Spacer()
                Button {
                    model.showsSettings.toggle()
                } label: {
                    Image(systemName: model.showsSettings ? "slider.horizontal.3" : "gearshape")
                }
                .buttonStyle(.borderless)
                .help(model.showsSettings ? "Show controls" : "Settings")
                .accessibilityLabel(model.showsSettings ? "Show controls" : "Settings")
                Toggle("Adjustments", isOn: $model.enabled)
                    .labelsHidden()
                    .accessibilityLabel("Adjustments enabled")
            }

            if model.showsSettings {
                settingsPanel
            } else {
                controlsPanel
            }

            Divider()
            HStack {
                Button("Full editor") { openFullEditor() }
                Spacer()
                Button("Quit") { quit() }
            }
        }
        .padding(14)
        .frame(width: 340, height: 530)
    }

    private var controlsPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            if model.displays.isEmpty {
                Label("No displays available", systemImage: "display.trianglebadge.exclamationmark")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Display", selection: Binding(
                    get: { model.selectedDisplayID },
                    set: { model.selectDisplay($0) }
                )) {
                    ForEach(model.displays) { display in
                        Text(display.isMain ? "\(display.name) · Main" : display.name).tag(display.id)
                    }
                }
                .pickerStyle(.menu)
            }

            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Picker("Mode", selection: $model.interfaceMode) {
                Text("Beginner").tag(InterfaceMode.beginner)
                Text("Professional").tag(InterfaceMode.professional)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    tonePreview
                    if model.interfaceMode == .beginner {
                        slider("Brightness", value: $model.settings.brightness, range: 0.1...1, neutral: 1)
                        slider("Contrast", value: $model.settings.contrast, range: 0.5...1.5, neutral: 1)
                        slider("Gamma", value: $model.settings.gamma, range: 0.5...3, neutral: 1,
                               name: "Gamma shadow boost", scale: 1, unit: "×")
                        slider("Warmth", value: $model.settings.warmth, range: -1...1, neutral: 0, color: .orange)
                        ColorPicker("Tint color", selection: tintColor, supportsOpacity: false)
                        slider("Tint strength", value: $model.settings.tintStrength, range: 0...1, neutral: 0, color: .pink)
                    } else {
                        slider("Brightness", value: $model.settings.brightness, range: 0.1...1, neutral: 1)
                        slider("Contrast", value: $model.settings.contrast, range: 0.5...1.5, neutral: 1)
                        slider("Gamma", value: $model.settings.gamma, range: 0.5...3, neutral: 1,
                               name: "Gamma shadow boost", scale: 1, unit: "×")
                        Picker("Tone region", selection: $region) {
                            Text("Shadows").tag(0)
                            Text("Midtones").tag(1)
                            Text("Highlights").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        switch region {
                        case 0:
                            slider("Red", value: $model.settings.redLift, range: -0.2...0.2, neutral: 0, color: .red, name: "Red shadow lift")
                            slider("Green", value: $model.settings.greenLift, range: -0.2...0.2, neutral: 0, color: .green, name: "Green shadow lift")
                            slider("Blue", value: $model.settings.blueLift, range: -0.2...0.2, neutral: 0, color: .blue, name: "Blue shadow lift")
                        case 1:
                            slider("Red", value: $model.settings.redGamma, range: 0.5...2, neutral: 1, color: .red, name: "Red midtone gamma", scale: 1, unit: "×")
                            slider("Green", value: $model.settings.greenGamma, range: 0.5...2, neutral: 1, color: .green, name: "Green midtone gamma", scale: 1, unit: "×")
                            slider("Blue", value: $model.settings.blueGamma, range: 0.5...2, neutral: 1, color: .blue, name: "Blue midtone gamma", scale: 1, unit: "×")
                        default:
                            slider("Red", value: $model.settings.redGain, range: 0.1...1.5, neutral: 1, color: .red, name: "Red highlight gain")
                            slider("Green", value: $model.settings.greenGain, range: 0.1...1.5, neutral: 1, color: .green, name: "Green highlight gain")
                            slider("Blue", value: $model.settings.blueGain, range: 0.1...1.5, neutral: 1, color: .blue, name: "Blue highlight gain")
                        }
                    }
                    Button("Reset this display") { model.resetSelected() }
                        .disabled(model.displays.isEmpty)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxHeight: .infinity)
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Show in", selection: $model.placement) {
                Text("Dock").tag(AppPlacement.dock)
                Text("Menu bar").tag(AppPlacement.menuBar)
            }
            .pickerStyle(.segmented)

            Toggle("Toggle adjustments with ⌃⌥⌘C", isOn: $model.hotkeyEnabled)
            if let status = model.hotkeyStatus {
                Text(status).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Refresh displays") { model.refreshDisplays() }
                Spacer()
                Button("Reset all") { model.resetAll() }
            }
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

    private var tonePreview: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(model.enabled ? "Estimated tone and color" : "Preview when enabled")
                .font(.caption.weight(.medium))
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(stops: previewStops, startPoint: .leading, endPoint: .trailing))
                .frame(height: 22)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.secondary.opacity(0.3)))
                .accessibilityLabel(model.enabled ? "Estimated black-to-white color ramp" : "Preview of black-to-white color ramp when enabled")
            HStack {
                Text("Black")
                Spacer()
                Text("Midtone")
                Spacer()
                Text("White")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var previewStops: [Gradient.Stop] {
        let baseline = (0...32).map { CGGammaValue($0) / 32 }
        let red = TransferCurve.adjust(baseline, settings: model.settings, channel: .red)
        let green = TransferCurve.adjust(baseline, settings: model.settings, channel: .green)
        let blue = TransferCurve.adjust(baseline, settings: model.settings, channel: .blue)
        return baseline.indices.map { index in
            Gradient.Stop(color: Color(red: Double(red[index]), green: Double(green[index]), blue: Double(blue[index])),
                          location: Double(index) / 32)
        }
    }

    private var tintColor: Binding<Color> {
        Binding(
            get: { Color(red: model.settings.tintRed, green: model.settings.tintGreen, blue: model.settings.tintBlue) },
            set: { value in
                guard let color = NSColor(value).usingColorSpace(.sRGB) else { return }
                var settings = model.settings
                settings.tintRed = Double(color.redComponent)
                settings.tintGreen = Double(color.greenComponent)
                settings.tintBlue = Double(color.blueComponent)
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
        color: Color = .accentColor,
        name: String? = nil,
        scale: Double = 100,
        unit: String = "%"
    ) -> some View {
        let label = name ?? title
        let precision = scale == 1 ? 2 : 0
        let clamped = Binding(
            get: { value.wrappedValue },
            set: { value.wrappedValue = min(max($0, range.lowerBound), range.upperBound) }
        )
        let displayed = Binding(
            get: { clamped.wrappedValue * scale },
            set: { clamped.wrappedValue = $0 / scale }
        )
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                TextField(label, value: displayed,
                          format: .number.precision(.fractionLength(precision)))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                    .accessibilityLabel("\(label) value")
                Text(unit).foregroundStyle(.secondary).frame(width: 15)
            }
            Slider(value: clamped, in: range, step: 0.01)
                .tint(color)
                .accessibilityLabel(label)
                .accessibilityValue("\((clamped.wrappedValue * scale).formatted(.number.precision(.fractionLength(precision))))\(unit)")
                .accessibilityHint("Range \((range.lowerBound * scale).formatted()) to \((range.upperBound * scale).formatted())\(unit). Default \((neutral * scale).formatted())\(unit).")
        }
    }
}
