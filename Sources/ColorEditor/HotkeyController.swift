import Carbon

/// Registers one system-wide shortcut without monitoring other key presses.
final class HotkeyController {
    private static let signature: OSType = 0x43454454 // "CEDT"

    private let action: () -> Void
    private var handler: EventHandlerRef?
    private var hotkey: EventHotKeyRef?

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @discardableResult
    func start(
        keyCode: UInt32 = UInt32(kVK_ANSI_C),
        modifiers: UInt32 = UInt32(controlKey | optionKey | cmdKey)
    ) -> OSStatus {
        stop()

        var event = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                var identifier = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &identifier
                )
                guard status == noErr,
                      identifier.signature == HotkeyController.signature,
                      identifier.id == 1 else { return OSStatus(eventNotHandledErr) }
                Unmanaged<HotkeyController>.fromOpaque(context).takeUnretainedValue().action()
                return noErr
            },
            1,
            &event,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
        guard installStatus == noErr else { return installStatus }

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            EventHotKeyID(signature: Self.signature, id: 1),
            GetApplicationEventTarget(),
            UInt32(kEventHotKeyExclusive),
            &hotkey
        )
        if registerStatus != noErr { stop() }
        return registerStatus
    }

    func stop() {
        if let hotkey { UnregisterEventHotKey(hotkey) }
        if let handler { RemoveEventHandler(handler) }
        hotkey = nil
        handler = nil
    }

    deinit { stop() }
}
