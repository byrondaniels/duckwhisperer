import AppKit
import ApplicationServices
import Foundation

struct PasteTarget {
    let application: NSRunningApplication?
    let element: AXUIElement?
    let pid: pid_t?
    let selectedRange: CFRange?
}
enum PasteTargetDetector {
    static func captureFocusedEditableTarget() -> PasteTarget {
        let application = currentExternalFrontmostApplication()
        let editableElement = focusedEditableElement()
        var pid: pid_t?

        if let editableElement {
            var elementPID = pid_t()
            if AXUIElementGetPid(editableElement, &elementPID) == .success {
                pid = elementPID
            }
        }

        let selectedRange = editableElement.flatMap { selectedTextRange(of: $0) }
        let pidText = pid.map { String($0) } ?? "nil"
        let rangeText = selectedRange.map { "\($0.location),\($0.length)" } ?? "nil"
        AppLog.write("paste target captured app=\(application?.localizedName ?? "nil") pid=\(pidText) element=\(editableElement == nil ? "nil" : "editable") range=\(rangeText)")
        return PasteTarget(application: application, element: editableElement, pid: pid, selectedRange: selectedRange)
    }

    static func canAttemptPasteIntoFocusedTarget() -> Bool {
        guard AXIsProcessTrusted(),
              let element = focusedUIElement()
        else {
            return false
        }

        return !elementBelongsToCurrentProcess(element)
    }

    static func focusCapturedTarget(_ target: PasteTarget) -> Bool {
        guard let element = target.element,
              AXIsProcessTrusted(),
              elementStillBelongsToExpectedProcess(element, target: target),
              isEditableTextTarget(element)
        else {
            AppLog.write("paste target focus restore failed before AX focus")
            return false
        }

        if let app = target.application, !app.isTerminated {
            app.activate(options: [.activateAllWindows])
        }

        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AppLog.write("paste target focus restore attempted")
        return true
    }

    static func insertTextDirectly(_ text: String, into target: PasteTarget) -> Bool {
        guard let element = target.element,
              AXIsProcessTrusted(),
              elementStillBelongsToExpectedProcess(element, target: target),
              isEditableTextTarget(element)
        else {
            AppLog.write("direct insert skipped; no captured editable AX element")
            return false
        }

        if AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString) == .success {
            AppLog.write("direct insert succeeded via AX selected text")
            return true
        }

        guard let value = stringAttribute(kAXValueAttribute as CFString, of: element) else {
            AppLog.write("direct insert failed; AX value unavailable")
            return false
        }

        let range = selectedTextRange(of: element)
            ?? target.selectedRange
            ?? CFRange(location: value.utf16.count, length: 0)
        guard range.location >= 0,
              range.length >= 0,
              range.location <= value.utf16.count,
              range.location + range.length <= value.utf16.count
        else {
            AppLog.write("direct insert failed; invalid range \(range.location),\(range.length) for length \(value.utf16.count)")
            return false
        }

        let newValue = (value as NSString).replacingCharacters(
            in: NSRange(location: range.location, length: range.length),
            with: text
        )
        let setValueResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newValue as CFString)
        guard setValueResult == .success else {
            AppLog.write("direct insert failed; setting AX value returned \(setValueResult.rawValue)")
            return false
        }

        var newSelection = CFRange(location: range.location + text.utf16.count, length: 0)
        if let newSelectionValue = AXValueCreate(.cfRange, &newSelection) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, newSelectionValue)
        }

        AppLog.write("direct insert succeeded via AX value replacement")
        return true
    }

    static func hasFocusedEditableTarget() -> Bool {
        guard AXIsProcessTrusted(),
              var element = focusedUIElement()
        else {
            return false
        }

        for _ in 0..<5 {
            if isEditableTextTarget(element) {
                return true
            }

            guard let parent = parentElement(of: element) else {
                return false
            }
            element = parent
        }

        return false
    }

    static func currentExternalFrontmostApplication() -> NSRunningApplication? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            return nil
        }
        return application
    }

    private static func elementBelongsToCurrentProcess(_ element: AXUIElement) -> Bool {
        var pid = pid_t()
        return AXUIElementGetPid(element, &pid) == .success
            && pid == ProcessInfo.processInfo.processIdentifier
    }

    private static func elementStillBelongsToExpectedProcess(_ element: AXUIElement, target: PasteTarget) -> Bool {
        var pid = pid_t()
        guard AXUIElementGetPid(element, &pid) == .success else {
            return false
        }
        if let targetPID = target.pid {
            return pid == targetPID
        }
        return pid != ProcessInfo.processInfo.processIdentifier
    }

    private static func focusedEditableElement() -> AXUIElement? {
        guard AXIsProcessTrusted(),
              var element = focusedUIElement()
        else {
            return nil
        }

        for _ in 0..<5 {
            if isEditableTextTarget(element),
               !elementBelongsToCurrentProcess(element) {
                return element
            }

            guard let parent = parentElement(of: element) else {
                return nil
            }
            element = parent
        }

        return nil
    }

    private static func focusedUIElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )

        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private static func parentElement(of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXParentAttribute as CFString,
            &value
        )

        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private static func isEditableTextTarget(_ element: AXUIElement) -> Bool {
        let textRoles = [
            kAXTextAreaRole as String,
            kAXTextFieldRole as String,
            kAXComboBoxRole as String
        ]

        if let role = stringAttribute(kAXRoleAttribute as CFString, of: element),
           textRoles.contains(role) {
            return true
        }

        return isAttributeSettable(kAXValueAttribute as CFString, of: element)
            && hasAttribute(kAXSelectedTextRangeAttribute as CFString, of: element)
    }

    private static func stringAttribute(_ attribute: CFString, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else {
            return nil
        }
        return value as? String
    }

    private static func hasAttribute(_ attribute: CFString, of element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute, &value) == .success
    }

    private static func selectedTextRange(of element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else {
            return nil
        }
        return range
    }

    private static func isAttributeSettable(_ attribute: CFString, of element: AXUIElement) -> Bool {
        var isSettable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute, &isSettable) == .success
            && isSettable.boolValue
    }
}
