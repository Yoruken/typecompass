import AppKit
@preconcurrency import ApplicationServices
import Carbon
import Combine
import TypeCompassCore

@MainActor
final class LiveInputMonitor: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var isReplaying = false
    @Published private(set) var status = L10n.text("Live assistance is off.")
    @Published private(set) var recoveryText = ""
    @Published private(set) var accessibilityAllowed = AXIsProcessTrusted()
    @Published private(set) var inputMonitoringAllowed = CGPreflightListenEventAccess()

    private struct Session {
        let field: FocusedText
        let boundary: CompositionBoundary
        let sourceID: String
        let language: InputLanguage
        var keys: [RawKeystroke]
        var updated = Date()
        var raw: String { keys.map(\.character).joined() }
    }

    private struct Suggestion {
        let language: InputLanguage
        let snapshot: TextSnapshot
        let canRewrite: Bool
    }

    private let store: InputSourceStore
    private let panel = SuggestionPanel()
    private let detector = LanguageDetector()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timer: Timer?
    private var session: Session?
    private var suggestion: Suggestion?
    private var revision = UUID()
    private var swallowedReturn = false
    private let eventTag: Int64 = 0x5459434F4D504153

    init(store: InputSourceStore) { self.store = store }

    func refreshPermissions() {
        accessibilityAllowed = AXIsProcessTrusted()
        inputMonitoringAllowed = CGPreflightListenEventAccess()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        refreshPermissions()
    }

    func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        refreshPermissions()
    }

    func start() {
        guard !isEnabled else { return }
        refreshPermissions()
        guard accessibilityAllowed, inputMonitoringAllowed else {
            status = L10n.text("Allow Accessibility and Input Monitoring, then enable live assistance again.")
            return
        }
        store.refresh()
        guard store.hasDistinctMappings else {
            status = L10n.text("Choose three distinct input sources before enabling live assistance.")
            return
        }
        let mask = [CGEventType.keyDown, .keyUp, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
            .reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, info in
                guard let info else { return Unmanaged.passUnretained(event) }
                // This source is installed only on the main run loop below.
                let consumed = MainActor.assumeIsolated {
                    Unmanaged<LiveInputMonitor>.fromOpaque(info).takeUnretainedValue().receive(type, event) == nil
                }
                return consumed ? nil : Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()
        ), let source = CFMachPortCreateRunLoopSource(nil, created, 0) else {
            status = L10n.text("macOS could not start observation. Check permissions and relaunch the app.")
            return
        }
        tap = created
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        isEnabled = true
        status = L10n.text("Listening for a new input segment. Confirm suggestions with ⌃⌥↩.")
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        revision = UUID()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        timer?.invalidate()
        timer = nil
        isEnabled = false
        clearSession()
        status = L10n.text("Live assistance is off.")
    }

    func clearRecovery() { recoveryText = "" }

    private func clearSession() {
        session = nil
        suggestion = nil
        panel.hide()
    }

    private func tick() {
        guard isEnabled, !isReplaying else { return }
        guard AXIsProcessTrusted(), CGPreflightListenEventAccess() else { stop(); return }
        guard let session else { return }
        store.refresh()
        guard Date().timeIntervalSince(session.updated) < 8,
              !IsSecureEventInputEnabled(), session.field.isCurrent(),
              store.currentID == session.sourceID else { clearSession(); return }
    }

    private func receive(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Never resume a partially observed segment after losing events.
            stop()
            status = L10n.text("Observation was interrupted by macOS. Enable it again to start a fresh segment.")
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.eventSourceUserData) != eventTag else { return Unmanaged.passUnretained(event) }
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if type == .keyUp {
            if code == 36 && swallowedReturn { swallowedReturn = false; return nil }
            return Unmanaged.passUnretained(event)
        }
        guard isEnabled else { return Unmanaged.passUnretained(event) }
        if isReplaying {
            // A real key/click interrupts further mutations. Never swallow new typing.
            revision = UUID()
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { clearSession(); return Unmanaged.passUnretained(event) }
        let modifiers = event.flags.intersection([.maskControl, .maskAlternate, .maskCommand, .maskShift, .maskAlphaShift])
        if code == 36, modifiers == [.maskControl, .maskAlternate], let suggestion, let session {
            swallowedReturn = true
            guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return nil }
            confirm(session, suggestion)
            return nil
        }
        guard modifiers.intersection([.maskControl, .maskAlternate, .maskCommand, .maskAlphaShift]).isEmpty,
              !IsSecureEventInputEnabled() else { clearSession(); return Unmanaged.passUnretained(event) }
        store.refresh()
        guard let field = FocusedText.current(), let snapshot = field.snapshot(),
              let language = store.language(for: store.currentID) else {
            clearSession()
            return Unmanaged.passUnretained(event)
        }
        if let existing = session,
           (!existing.field.isCurrent() || existing.sourceID != store.currentID
            || Date().timeIntervalSince(existing.updated) >= 8
            || existing.boundary.insertion(in: snapshot) == nil) {
            clearSession()
        }
        if code == 51 {
            // IME Backspace may remove a kana/syllable or revert conversion,
            // rather than undo exactly one raw key. Do not guess its effect.
            if session?.language == .english, !(session?.keys.isEmpty ?? true) {
                session?.keys.removeLast()
                session?.updated = Date()
                if session?.keys.isEmpty == true { clearSession() }
            } else { clearSession() }
        } else if let key = RawKeystroke(keyCode: code, shifted: modifiers.contains(.maskShift)) {
            if session == nil, let boundary = CompositionBoundary(baseline: snapshot) {
                session = Session(field: field, boundary: boundary, sourceID: store.currentID, language: language, keys: [])
            }
            guard (session?.keys.count ?? 64) < 64 else { clearSession(); return Unmanaged.passUnretained(event) }
            session?.keys.append(key)
            session?.updated = Date()
        } else {
            // Space/Return/Tab, digits, navigation, Escape, paste and shortcuts are
            // commit/candidate boundaries. Do not carry their preceding text forward.
            clearSession()
        }
        suggestion = nil
        panel.hide()
        let stamp = UUID()
        revision = stamp
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, self.revision == stamp else { return }
            self.evaluate()
        }
        return Unmanaged.passUnretained(event)
    }

    private func evaluate() {
        guard !isReplaying, let session, session.field.isCurrent(),
              let language = detector.detect(session.raw).language,
              language != session.language, !store.mappedID(for: language).isEmpty,
              let snapshot = session.field.snapshot(),
              session.boundary.insertion(in: snapshot) != nil else { return }
        let canRewrite = session.boundary.canRewrite(snapshot, requiresMarkedText: session.language != .english)
            && (session.language != .english || insertedText(session, snapshot) == session.raw)
        suggestion = Suggestion(language: language, snapshot: snapshot, canRewrite: canRewrite)
        panel.show(raw: session.raw, language: language, canRewrite: canRewrite, caret: session.field.caretRect())
        status = L10n.format("Did you mean %@?", language.title)
    }

    private func insertedText(_ session: Session, _ snapshot: TextSnapshot) -> String? {
        guard let range = session.boundary.insertion(in: snapshot) else { return nil }
        return (snapshot.text as NSString).substring(with: range)
    }

    private func confirm(_ session: Session, _ suggestion: Suggestion) {
        guard suggestion.canRewrite else {
            status = L10n.text("This field does not expose a verifiable composition range. Retyping is unavailable.")
            return
        }
        store.refresh()
        guard session.field.isCurrent(), store.currentID == session.sourceID,
              session.field.snapshot() == suggestion.snapshot else { clearSession(); return }
        let targetID = store.mappedID(for: suggestion.language)
        guard !targetID.isEmpty else { clearSession(); return }
        isReplaying = true
        recoveryText = session.raw
        clearSession()
        let stamp = UUID()
        revision = stamp
        Task { await rewrite(session, targetID: targetID, target: suggestion.language, stamp: stamp) }
    }

    private enum RewriteError: Error { case changed, unavailable }

    private func checked(_ session: Session, stamp: UUID, sourceID: String) throws -> TextSnapshot {
        store.refresh()
        guard isEnabled, revision == stamp, !IsSecureEventInputEnabled(),
              session.field.isCurrent(), store.currentID == sourceID,
              let current = session.field.snapshot(), session.boundary.insertion(in: current) != nil else {
            throw RewriteError.changed
        }
        return current
    }

    private func pause() async throws { try await Task.sleep(for: .milliseconds(65)) }

    private func post(_ code: UInt16, shifted: Bool = false, to pid: pid_t) throws {
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) else { throw RewriteError.unavailable }
        for event in [down, up] {
            event.flags = shifted ? .maskShift : []
            event.setIntegerValueField(.eventSourceUserData, value: eventTag)
            event.postToPid(pid)
        }
    }

    private func rewrite(_ session: Session, targetID: String, target: InputLanguage, stamp: UUID) async {
        defer { isReplaying = false }
        var sent = 0
        do {
            status = L10n.text("Clearing only the current input segment…")
            let requiresMarked = session.language != .english
            var current = try checked(session, stamp: stamp, sourceID: session.sourceID)
            guard session.boundary.canRewrite(current, requiresMarkedText: requiresMarked) else { throw RewriteError.changed }
            if case .range = current.marked {
                try post(53, to: session.field.pid) // Ask the IME to cancel its composition first.
                try await pause()
            }
            var cleared = false
            for _ in 0..<(session.keys.count * 2 + 4) {
                current = try checked(session, stamp: stamp, sourceID: session.sourceID)
                if session.boundary.isCleared(current, requiresMarkedText: requiresMarked) { cleared = true; break }
                guard session.boundary.canRewrite(current, requiresMarkedText: requiresMarked),
                      let inserted = session.boundary.insertion(in: current),
                      NSMaxRange(current.selection) == NSMaxRange(inserted) else { throw RewriteError.changed }
                // One backspace, then re-read the field. Never select all, replace
                // the entire value, or blindly delete a raw-key-sized text range.
                try post(51, to: session.field.pid)
                try await pause()
            }
            guard cleared else { throw RewriteError.unavailable }
            _ = try checked(session, stamp: stamp, sourceID: session.sourceID)
            guard store.activate(id: targetID) else { throw RewriteError.unavailable }
            try await pause()
            current = try checked(session, stamp: stamp, sourceID: targetID)
            guard session.boundary.isCleared(current, requiresMarkedText: false) else { throw RewriteError.changed }
            for key in session.keys {
                _ = try checked(session, stamp: stamp, sourceID: targetID)
                try post(key.keyCode, shifted: key.shifted, to: session.field.pid)
                sent += 1
                try await pause()
            }
            current = try checked(session, stamp: stamp, sourceID: targetID)
            if target == .english {
                guard insertedText(session, current) == session.raw else { throw RewriteError.unavailable }
            } else {
                guard session.boundary.canRewrite(current, requiresMarkedText: true) else { throw RewriteError.unavailable }
            }
            recoveryText = ""
            status = L10n.format("Switched to %@ and retyped the input. Confirm any remaining candidates normally.", target.title)
        } catch {
            // Keep the original raw input in memory for explicit manual recovery.
            // A focus change must never cause rollback typing into a different field.
            status = L10n.format("Retyping stopped after %d of %d keys. Original input is available below; check the target field before recovering.", sent, session.keys.count)
            NSSound.beep()
        }
    }
}
