import AppKit
import SwiftUI
import TypeCompassCore

@MainActor
final class SuggestionPanel {
    private let panel: NSPanel = {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        return panel
    }()

    func show(raw: String, language: InputLanguage, canRewrite: Bool, caret: CGRect?) {
        let view = VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(.teal)
                Text(L10n.format("Did you mean %@?", language.title)).font(.headline)
            }
            Text(raw).font(.system(.body, design: .monospaced)).lineLimit(2)
            Text(L10n.text(canRewrite
                ? "⌃⌥↩ Confirm: clear this composition, switch and retype."
                : "This field does not expose a verifiable composition range. Retyping is unavailable."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14).frame(width: 340, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        let host = NSHostingView(rootView: view)
        panel.contentView = host
        let size = host.fittingSize
        let anchor = caret.flatMap { rect in
            NSScreen.screens.first.map { CGPoint(x: rect.minX, y: $0.frame.maxY - rect.minY) }
        }
        let screen = NSScreen.screens.first(where: { NSMouseInRect(anchor ?? NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        var origin = CGPoint(x: visible.midX - size.width / 2, y: visible.minY + 70)
        if let anchor {
            // AX uses top-left screen coordinates; AppKit uses bottom-left.
            // Prefer above the caret to leave the usual candidate area below it free.
            origin = CGPoint(x: anchor.x, y: anchor.y + 12)
        }
        origin.x = max(visible.minX + 8, min(origin.x, visible.maxX - size.width - 8))
        origin.y = max(visible.minY + 8, min(origin.y, visible.maxY - size.height - 8))
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }

    func hide() { panel.orderOut(nil); panel.contentView = nil }
}
