import SwiftUI
import TypeCompassCore

struct LiveAssistanceView: View {
    @ObservedObject var monitor: LiveInputMonitor

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(get: { monitor.isEnabled }, set: { $0 ? monitor.start() : monitor.stop() })) {
                    Label(L10n.text("Live input assistance"), systemImage: "text.cursor").font(.headline)
                }
                .disabled(monitor.isReplaying)
                Text(L10n.text("Type in another app. A language hint appears without taking focus. Press Control + Option + Return to clear this segment, switch and retype."))
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button(L10n.text("Allow Accessibility")) { monitor.requestAccessibility() }
                        .disabled(monitor.accessibilityAllowed)
                    Image(systemName: monitor.accessibilityAllowed ? "checkmark.circle.fill" : "circle")
                        .accessibilityLabel(L10n.text(monitor.accessibilityAllowed ? "Allowed" : "Not allowed"))
                    Button(L10n.text("Allow Input Monitoring")) { monitor.requestInputMonitoring() }
                        .disabled(monitor.inputMonitoringAllowed)
                    Image(systemName: monitor.inputMonitoringAllowed ? "checkmark.circle.fill" : "circle")
                        .accessibilityLabel(L10n.text(monitor.inputMonitoringAllowed ? "Allowed" : "Not allowed"))
                    Button(L10n.text("Refresh")) { monitor.refreshPermissions() }
                }.font(.caption)
                Text(monitor.status).font(.callout).foregroundStyle(.secondary)
                Text(L10n.text("Experimental: QWERTY letters only. Field compatibility varies. Start a fresh segment after enabling. No typed content is saved or uploaded."))
                    .font(.caption).foregroundStyle(.secondary)
                if !monitor.recoveryText.isEmpty {
                    Divider()
                    Text(L10n.text("Original input for manual recovery")).font(.headline)
                    Text(monitor.recoveryText).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    Button(L10n.text("Clear recovery text")) { monitor.clearRecovery() }
                        .disabled(monitor.isReplaying)
                }
            }.padding(10)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            monitor.refreshPermissions()
        }
    }
}
