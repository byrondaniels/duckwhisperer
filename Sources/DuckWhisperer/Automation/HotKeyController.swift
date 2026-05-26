import Carbon.HIToolbox
import Foundation

struct RecordShortcutPreset: Equatable {
    let id: String
    let title: String
    let keyCode: UInt32
    let modifiers: UInt32

    static let all: [RecordShortcutPreset] = [
        RecordShortcutPreset(id: "option-space", title: "Option + Space",
                             keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)),
        RecordShortcutPreset(id: "cmd-shift-space", title: "Command + Shift + Space",
                             keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | shiftKey)),
        RecordShortcutPreset(id: "ctrl-space", title: "Control + Space",
                             keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey)),
        RecordShortcutPreset(id: "option-shift-d", title: "Option + Shift + D",
                             keyCode: UInt32(kVK_ANSI_D), modifiers: UInt32(optionKey | shiftKey)),
        RecordShortcutPreset(id: "cmd-ctrl-d", title: "Command + Control + D",
                             keyCode: UInt32(kVK_ANSI_D), modifiers: UInt32(cmdKey | controlKey))
    ]

    static var defaultPreset: RecordShortcutPreset { all[0] }

    static func preset(for id: String?) -> RecordShortcutPreset {
        all.first { $0.id == id } ?? defaultPreset
    }

    static var currentSelected: RecordShortcutPreset {
        preset(for: UserDefaults.standard.string(forKey: recordShortcutPresetIDKey))
    }
}

private var globalHotKeyAction: ((UInt32) -> Void)?

private let hotKeyEventHandler: EventHandlerUPP = { _, eventRef, _ in
    guard let eventRef else {
        return noErr
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        eventRef,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    if status == noErr, hotKeyID.signature == hotKeySignature {
        DispatchQueue.main.async {
            globalHotKeyAction?(hotKeyID.id)
        }
    }

    return noErr
}
final class HotKeyController {
    private var recordHotKeyRef: EventHotKeyRef?
    private var cancelHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func register(action: @escaping (UInt32) -> Void) -> OSStatus {
        globalHotKeyAction = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            return handlerStatus
        }

        return registerRecordHotKey(preset: RecordShortcutPreset.currentSelected)
    }

    @discardableResult
    func reregisterRecordHotKey(preset: RecordShortcutPreset) -> OSStatus {
        if let recordHotKeyRef {
            UnregisterEventHotKey(recordHotKeyRef)
            self.recordHotKeyRef = nil
        }
        return registerRecordHotKey(preset: preset)
    }

    private func registerRecordHotKey(preset: RecordShortcutPreset) -> OSStatus {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: recordHotKeyIdentifier)
        let status = RegisterEventHotKey(
            preset.keyCode,
            preset.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef {
            recordHotKeyRef = hotKeyRef
        }
        return status
    }

    func registerCancelHotKey() -> OSStatus {
        guard cancelHotKeyRef == nil else {
            return noErr
        }

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: cancelHotKeyIdentifier)
        let status = RegisterEventHotKey(
            UInt32(kVK_Escape),
            0,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef {
            cancelHotKeyRef = hotKeyRef
        }
        return status
    }

    func unregisterCancelHotKey() {
        guard let cancelHotKeyRef else {
            return
        }

        UnregisterEventHotKey(cancelHotKeyRef)
        self.cancelHotKeyRef = nil
    }

    deinit {
        unregisterCancelHotKey()
        if let recordHotKeyRef {
            UnregisterEventHotKey(recordHotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}
