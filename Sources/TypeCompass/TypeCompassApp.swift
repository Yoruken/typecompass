import SwiftUI
import TypeCompassCore

@main
struct TypeCompassApp: App {
    @StateObject private var store: InputSourceStore
    @StateObject private var monitor: LiveInputMonitor

    init() {
        let store = InputSourceStore()
        _store = StateObject(wrappedValue: store)
        _monitor = StateObject(wrappedValue: LiveInputMonitor(store: store))
    }

    var body: some Scene {
        Window("TypeCompass", id: "main") {
            ContentView(store: store, monitor: monitor)
        }
        .defaultSize(width: 680, height: 680)
        .windowResizability(.contentSize)

        MenuBarExtra("TypeCompass", systemImage: "location.north.circle") {
            SourceMenu(store: store, monitor: monitor)
        }
    }
}

private struct SourceMenu: View {
    @ObservedObject var store: InputSourceStore
    @ObservedObject var monitor: LiveInputMonitor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(L10n.format("Current: %@", store.currentName))
        Button(L10n.text(monitor.isEnabled ? "Pause live assistance" : "Enable live assistance")) {
            monitor.isEnabled ? monitor.stop() : monitor.start()
        }
        .disabled(monitor.isReplaying)
        Text(monitor.status)
        Divider()
        ForEach(InputLanguage.allCases) { language in
            Button(language.title) { store.select(language) }
                .disabled(store.mappedID(for: language).isEmpty)
        }
        Divider()
        Text(store.status)
        Button(L10n.text("Refresh input sources")) { store.refresh() }
        Button(L10n.text("Open TypeCompass…")) {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button(L10n.text("Quit TypeCompass")) { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
