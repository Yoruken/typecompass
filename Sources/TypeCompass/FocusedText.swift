import AppKit
import ApplicationServices
import Carbon
import TypeCompassCore

/// An AX field identity is retained only for the current short input session.
struct FocusedText {
    let element: AXUIElement
    let pid: pid_t

    static func current() -> FocusedText? {
        guard !IsSecureEventInputEnabled(), AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.05)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let element = value as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.05)
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid == app.processIdentifier else { return nil }
        let field = FocusedText(element: element, pid: pid)
        guard let role = field.string(kAXRoleAttribute),
              [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role) else { return nil }
        let subrole = field.string(kAXSubroleAttribute)
        guard subrole != kAXSecureTextFieldSubrole,
              subrole != nil || role == kAXTextAreaRole else { return nil }
        return field
    }

    func isCurrent() -> Bool {
        guard let other = Self.current() else { return false }
        return pid == other.pid && CFEqual(element, other.element)
    }

    func snapshot() -> TextSnapshot? {
        guard !IsSecureEventInputEnabled(),
              let text = string(kAXValueAttribute), text.utf16.count <= 16_384,
              let selection = range(kAXSelectedTextRangeAttribute),
              selection.location >= 0, selection.length >= 0,
              selection.location <= text.utf16.count,
              selection.length <= text.utf16.count - selection.location else { return nil }
        // Optional AX attribute exposed by some text clients. It is NOT a
        // universally supported API. Unsupported fields cannot rewrite CJK input.
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, "AXTextInputMarkedRange" as CFString, &value)
        let marked: MarkedText
        if result == .noValue {
            marked = .none
        } else if result == .success, let value, let range = Self.decodeRange(value) {
            if range.location == NSNotFound || range.location == -1 || range.length == 0 {
                marked = .none
            } else if range.location >= 0, range.length > 0,
                      range.location <= text.utf16.count,
                      range.length <= text.utf16.count - range.location {
                marked = .range(range)
            } else { marked = .unavailable }
        } else { marked = .unavailable }
        return TextSnapshot(text: text, selection: selection, marked: marked)
    }

    func caretRect() -> CGRect? {
        guard let range = range(kAXSelectedTextRangeAttribute) else { return nil }
        var input = CFRange(location: range.location, length: 0)
        guard let parameter = AXValueCreate(.cfRange, &input) else { return nil }
        var output: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, parameter, &output) == .success,
              let output, CFGetTypeID(output) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(output as! AXValue, .cgRect, &rect), !rect.isInfinite, !rect.isNull else { return nil }
        return rect
    }

    private func attribute(_ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        return result
    }

    private func string(_ name: String) -> String? { attribute(name) as? String }
    private func range(_ name: String) -> NSRange? { attribute(name).flatMap(Self.decodeRange) }

    private static func decodeRange(_ value: CFTypeRef) -> NSRange? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
        return NSRange(location: range.location, length: range.length)
    }
}
