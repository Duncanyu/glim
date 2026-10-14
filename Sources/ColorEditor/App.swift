import AppKit
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
        updateHotkey(enabled: model.hotkeyEnabled)
        openEditor()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openEditor() }
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
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 680),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Color Editor"
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
        openEditor()
    }

    @objc private func toggleAdjustments() { model.enabled.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func updatePlacement(_ placement: AppPlacement) {
        switch placement {
        case .menuBar:
            if statusItem == nil { installStatusItem() }
            NSApp.setActivationPolicy(.accessory)
        case .dock:
            NSApp.setActivationPolicy(.regular)
            if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
            statusItem = nil
            NSApp.activate(ignoringOtherApps: true)
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
        statusItem?.button?.image = NSImage(systemSymbolName: enabled ? "circle.lefthalf.filled" : "circle.slash", accessibilityDescription: enabled ? "Color Editor enabled" : "Color Editor paused")
        statusItem?.button?.toolTip = enabled ? "Color Editor: adjustments on" : "Color Editor: adjustments paused"
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(menuItem("Open Color Editor", action: #selector(openEditor)))
        menu.addItem(menuItem("Settings…", action: #selector(openSettings)))
        menu.addItem(.separator())
        let toggle = menuItem("Pause Adjustments", action: #selector(toggleAdjustments))
        toggle.tag = 1
        menu.addItem(toggle)
        menu.addItem(.separator())
        menu.addItem(menuItem("Quit Color Editor", action: #selector(quit)))
        item.menu = menu
        statusItem = item
        updateStatusItem(enabled: model.enabled)
    }

    private func installAppMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem(title: "Color Editor", action: nil, keyEquivalent: "")
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
        let quit = menuItem("Quit Color Editor", action: #selector(quit))
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
