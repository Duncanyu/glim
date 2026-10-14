import AppKit
import SwiftUI

@main
struct ColorEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = EditorModel()

    var body: some Scene {
        WindowGroup("Color Editor", id: "editor") {
            EditorRoot(model: model, appDelegate: appDelegate)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

private struct EditorRoot: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var model: EditorModel
    let appDelegate: AppDelegate

    var body: some View {
        EditorView(model: model)
            .frame(minWidth: 430, minHeight: 570)
            .onAppear {
                appDelegate.configure(model: model, reopen: { openWindow(id: "editor") })
            }
            .onChange(of: model.placement) { _, placement in
                appDelegate.updatePlacement(placement)
            }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var model: EditorModel?
    private var reopen: (() -> Void)?
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    func configure(model: EditorModel, reopen: @escaping () -> Void) {
        self.reopen = reopen
        guard self.model == nil else { return }
        self.model = model
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(displaysChanged), name: NSWorkspace.didWakeNotification, object: nil)
        updatePlacement(model.placement)
    }

    func updatePlacement(_ placement: AppPlacement) {
        switch placement {
        case .menuBar:
            if statusItem == nil { installStatusItem() }
            NSApp.setActivationPolicy(.accessory)
        case .dock:
            NSApp.setActivationPolicy(.regular)
            if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
            statusItem = nil
            menu = nil
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openEditor() }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.restoreDisplays()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.item(withTag: 1)?.title = model?.enabled == true ? "Pause Adjustments" : "Resume Adjustments"
    }

    @objc private func displaysChanged() { model?.refreshDisplays() }

    @objc private func openEditor() {
        if let window = NSApp.windows.first(where: { $0.title == "Color Editor" && $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            reopen?()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleAdjustments() { model?.enabled.toggle() }

    @objc private func openSettings() {
        model?.showsSettings = true
        openEditor()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "Color Editor")
        item.button?.toolTip = "Color Editor"

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "Open Color Editor", action: #selector(openEditor), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        let toggle = NSMenuItem(title: "Pause Adjustments", action: #selector(toggleAdjustments), keyEquivalent: "")
        toggle.tag = 1
        menu.addItem(toggle)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Color Editor", action: #selector(quit), keyEquivalent: ""))
        for entry in menu.items { entry.target = self }
        item.menu = menu
        self.statusItem = item
        self.menu = menu
    }
}
