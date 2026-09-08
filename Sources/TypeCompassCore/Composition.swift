import Foundation

public enum MarkedText: Equatable, Sendable {
    case unavailable
    case none
    case range(NSRange)
}

public struct TextSnapshot: Equatable, Sendable {
    public let text: String
    public let selection: NSRange
    public let marked: MarkedText

    public init(text: String, selection: NSRange, marked: MarkedText) {
        self.text = text
        self.selection = selection
        self.marked = marked
    }
}

/// Identifies only an insertion at the original caret. All ranges use UTF-16,
/// matching Cocoa/AX. Never uses the raw-key count as a document deletion count.
public struct CompositionBoundary: Sendable {
    public let baseline: TextSnapshot

    public init?(baseline: TextSnapshot) {
        guard baseline.selection.length == 0,
              baseline.selection.location >= 0,
              baseline.selection.location <= (baseline.text as NSString).length,
              baseline.marked == .none || baseline.marked == .unavailable else { return nil }
        self.baseline = baseline
    }

    public func insertion(in current: TextSnapshot) -> NSRange? {
        let original = baseline.text as NSString
        let value = current.text as NSString
        let start = baseline.selection.location
        let count = value.length - original.length
        guard count >= 0, count <= 512,
              value.substring(to: start) == original.substring(to: start),
              value.substring(from: start + count) == original.substring(from: start),
              current.selection.location >= start,
              current.selection.length >= 0,
              current.selection.location <= start + count,
              current.selection.length <= start + count - current.selection.location else { return nil }
        return NSRange(location: start, length: count)
    }

    public func canRewrite(_ current: TextSnapshot, requiresMarkedText: Bool) -> Bool {
        guard let inserted = insertion(in: current), inserted.length > 0 else { return false }
        switch current.marked {
        case .range(let marked): return marked == inserted
        case .none, .unavailable:
            return !requiresMarkedText && current.selection.length == 0
                && current.selection.location == NSMaxRange(inserted)
        }
    }

    public func isCleared(_ current: TextSnapshot, requiresMarkedText: Bool) -> Bool {
        guard current.text == baseline.text, current.selection == baseline.selection else { return false }
        switch current.marked {
        case .none: return true
        case .unavailable: return !requiresMarkedText
        case .range: return false
        }
    }
}

public struct RawKeystroke: Equatable, Sendable {
    public let keyCode: UInt16
    public let shifted: Bool
    public let character: String

    public init?(keyCode: UInt16, shifted: Bool) {
        let letters: [UInt16: String] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v",
            11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t", 31: "o", 32: "u",
            34: "i", 35: "p", 37: "l", 38: "j", 40: "k", 45: "n", 46: "m", 39: "'"
        ]
        guard let letter = letters[keyCode], !(keyCode == 39 && shifted) else { return nil }
        self.keyCode = keyCode
        self.shifted = shifted
        self.character = shifted ? letter.uppercased() : letter
    }
}
