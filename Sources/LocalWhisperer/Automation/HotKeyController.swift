import Carbon.HIToolbox
import Foundation

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
    private var hotKeyRefs: [EventHotKeyRef] = []
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

        let recordStatus = registerHotKey(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(optionKey),
            identifier: recordHotKeyIdentifier
        )
        guard recordStatus == noErr else {
            return recordStatus
        }

        return registerHotKey(
            keyCode: UInt32(kVK_ANSI_X),
            modifiers: UInt32(optionKey),
            identifier: translateSelectionHotKeyIdentifier
        )
    }

    private func registerHotKey(keyCode: UInt32, modifiers: UInt32, identifier: UInt32) -> OSStatus {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: identifier)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef {
            hotKeyRefs.append(hotKeyRef)
        }
        return status
    }

    deinit {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}
