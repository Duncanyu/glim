import AppKit
import CoreGraphics

@MainActor
final class EditorModel: ObservableObject {
    @Published var displays: [DisplayInfo] = []
    @Published var selectedDisplayID = CGMainDisplayID()
    @Published var settings = DisplaySettings() {
        didSet { saveSelectedSettings() }
    }
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "adjustmentsEnabled")
            applyAll()
        }
    }
    @Published var interfaceMode: InterfaceMode {
        didSet { UserDefaults.standard.set(interfaceMode.rawValue, forKey: "interfaceMode") }
    }
    @Published var placement: AppPlacement {
        didSet { UserDefaults.standard.set(placement.rawValue, forKey: "appPlacement") }
    }
    @Published var errorMessage: String?
    @Published var showsSettings = false

    private let controller = DisplayController()
    private var manualSettings: [String: DisplaySettings]
    private var automaticSettings: [String: DisplaySettings] = [:]
    private var automaticModeEnabled = false
    private var loadingSelection = false

    init() {
        let defaults = UserDefaults.standard
        enabled = defaults.object(forKey: "adjustmentsEnabled") as? Bool ?? true
        interfaceMode = InterfaceMode(rawValue: defaults.string(forKey: "interfaceMode") ?? "") ?? .beginner
        placement = AppPlacement(rawValue: defaults.string(forKey: "appPlacement") ?? "") ?? .menuBar
        manualSettings = (defaults.data(forKey: "displaySettings").flatMap { try? JSONDecoder().decode([String: DisplaySettings].self, from: $0) }) ?? [:]
        refreshDisplays()
    }

    func selectDisplay(_ id: CGDirectDisplayID) {
        guard let display = displays.first(where: { $0.id == id }) else { return }
        loadingSelection = true
        selectedDisplayID = id
        settings = manualSettings[display.key] ?? DisplaySettings()
        loadingSelection = false
        errorMessage = enabled ? apply(id) : nil
    }

    func resetSelected() { settings = DisplaySettings() }

    func resetAll() {
        manualSettings.removeAll()
        persistSettings()
        loadingSelection = true
        settings = DisplaySettings()
        loadingSelection = false
        applyAll()
    }

    func refreshDisplays() {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success else {
            errorMessage = "Could not enumerate connected displays."
            return
        }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        let result = ids.withUnsafeMutableBufferPointer { buffer in
            CGGetOnlineDisplayList(UInt32(buffer.count), buffer.baseAddress, &count)
        }
        guard result == .success else {
            errorMessage = "Could not enumerate connected displays."
            return
        }

        let screenNames: [CGDirectDisplayID: String] = Dictionary(uniqueKeysWithValues: NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            return (number.uint32Value, screen.localizedName)
        })
        var screens = ids.prefix(Int(count)).map { id -> DisplayInfo in
            let vendor = CGDisplayVendorNumber(id)
            let model = CGDisplayModelNumber(id)
            let serial = CGDisplaySerialNumber(id)
            let builtIn = CGDisplayIsBuiltin(id) != 0
            let name = screenNames[id] ?? "Mirrored display \(id)"
            let key = builtIn ? "built-in" : (serial == 0 ? "\(vendor)-\(model)-\(name)" : "\(vendor)-\(model)-\(serial)")
            return DisplayInfo(id: id, name: name, isMain: id == CGMainDisplayID(), key: key)
        }
        let keyCounts = Dictionary(grouping: screens, by: \.key).mapValues(\.count)
        screens = screens.map { display in
            guard keyCounts[display.key, default: 0] > 1 else { return display }
            return DisplayInfo(id: display.id, name: display.name, isMain: display.isMain, key: "session:\(display.id)")
        }
        displays = screens
        controller.forgetDisconnectedDisplays(keeping: Set(screens.map(\.id)))
        if let selected = screens.first(where: { $0.id == selectedDisplayID }) ?? screens.first {
            selectDisplay(selected.id)
        }
        applyAll()
    }

    // A later content analyzer can supply settings here without touching the manual UI or gamma backend.
    func useAutomaticAdjustments(_ active: Bool) {
        automaticModeEnabled = active
        applyAll()
    }

    func submitAutomaticAdjustment(_ adjustment: DisplaySettings?, for displayID: CGDirectDisplayID) {
        guard let key = displays.first(where: { $0.id == displayID })?.key else { return }
        automaticSettings[key] = adjustment
        if automaticModeEnabled { errorMessage = apply(displayID) }
    }

    func restoreDisplays() {
        if let error = controller.restoreAll() { NSLog("Color Editor could not restore a display curve: %@", error) }
    }

    private func saveSelectedSettings() {
        guard !loadingSelection, let key = displays.first(where: { $0.id == selectedDisplayID })?.key else { return }
        manualSettings[key] = settings
        persistSettings()
        if enabled && !automaticModeEnabled { errorMessage = apply(selectedDisplayID) }
    }

    private func persistSettings() {
        let stableSettings = manualSettings.filter { !$0.key.hasPrefix("session:") }
        guard let data = try? JSONEncoder().encode(stableSettings) else { return }
        UserDefaults.standard.set(data, forKey: "displaySettings")
    }

    private func applyAll() {
        guard enabled else {
            errorMessage = controller.restoreAll()
            return
        }
        var firstError: String?
        for display in displays {
            if let error = apply(display.id), firstError == nil { firstError = error }
        }
        errorMessage = firstError
    }

    @discardableResult
    private func apply(_ displayID: CGDirectDisplayID) -> String? {
        guard let display = displays.first(where: { $0.id == displayID }) else { return nil }
        let manual = manualSettings[display.key] ?? DisplaySettings()
        let adjustment = automaticModeEnabled ? (automaticSettings[display.key] ?? manual) : manual
        do {
            try controller.apply(adjustment, to: displayID)
            return nil
        } catch {
            return "\(display.name): \(error.localizedDescription)"
        }
    }
}
