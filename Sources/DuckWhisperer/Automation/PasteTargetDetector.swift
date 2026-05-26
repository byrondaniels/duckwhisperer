import AppKit
import ApplicationServices
import Foundation

struct PasteTarget {
    let application: NSRunningApplication?
    let element: AXUIElement?
    let pid: pid_t?
}

enum PasteBackSeverity: Equatable {
    case ready
    case warning
    case blocked
}

struct PasteBackReadiness {
    let severity: PasteBackSeverity
    let title: String
    let detail: String
    let actionTitle: String?

    var isReady: Bool {
        severity == .ready
    }

    var menuTitle: String {
        switch severity {
        case .ready:
            return "Paste-Back: Ready"
        case .warning:
            return "Paste-Back: Check Target"
        case .blocked:
            return "Paste-Back: Needs Permission"
        }
    }
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

        let pidText = pid.map { String($0) } ?? "nil"
        AppLog.write("paste target captured app=\(application?.localizedName ?? "nil") pid=\(pidText) element=\(editableElement == nil ? "nil" : "editable")")
        return PasteTarget(application: application, element: editableElement, pid: pid)
    }

    static func canAttemptPasteIntoFocusedTarget() -> Bool {
        guard AXIsProcessTrusted(),
              let element = focusedUIElement()
        else {
            return false
        }

        return !elementBelongsToCurrentProcess(element)
    }

    static func readiness(for target: PasteTarget? = nil) -> PasteBackReadiness {
        guard AXIsProcessTrusted() else {
            return PasteBackReadiness(
                severity: .blocked,
                title: "Paste-back permission is missing",
                detail: "macOS has not allowed DuckWhisperer to control the keyboard or target text fields yet.",
                actionTitle: "Open Permission Fix"
            )
        }

        if let target {
            if let appName = target.application?.localizedName, target.element != nil {
                return PasteBackReadiness(
                    severity: .ready,
                    title: "Target field captured",
                    detail: "DuckWhisperer found an editable field in \(appName) before recording started.",
                    actionTitle: nil
                )
            }

            if let appName = target.application?.localizedName {
                return PasteBackReadiness(
                    severity: .warning,
                    title: "Target app captured, field not confirmed",
                    detail: "DuckWhisperer saw \(appName), but macOS did not expose the exact text field. Clipboard paste can still work if the field accepts Command+V.",
                    actionTitle: "Click Field And Paste Again"
                )
            }
        }

        if hasFocusedEditableTarget() {
            return PasteBackReadiness(
                severity: .ready,
                title: "Focused text field detected",
                detail: "DuckWhisperer can see the current editable field and should be able to paste there.",
                actionTitle: nil
            )
        }

        if let appName = currentExternalFrontmostApplication()?.localizedName {
            return PasteBackReadiness(
                severity: .warning,
                title: "No editable field detected",
                detail: "DuckWhisperer can see \(appName), but not a focused text field. Click in the field before starting dictation.",
                actionTitle: "Click A Text Field"
            )
        }

        return PasteBackReadiness(
            severity: .warning,
            title: "No target app detected",
            detail: "Click in the app and field where you want text before starting dictation.",
            actionTitle: "Click A Text Field"
        )
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
            app.activate(options: [])
        }

        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AppLog.write("paste target focus restore attempted")
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

    private static func isAttributeSettable(_ attribute: CFString, of element: AXUIElement) -> Bool {
        var isSettable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute, &isSettable) == .success
            && isSettable.boolValue
    }
}
