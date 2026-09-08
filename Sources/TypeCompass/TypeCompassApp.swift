import SwiftUI
import TypeCompassCore

@main
struct TypeCompassApp: App {
    @StateObject private var store = InputSourceStore()

    var body: some Scene {
        Window("TypeCompass", id: "main") {
            ContentView(store: store)
        }
        .defaultSize(width: 680, height: 680)
        .windowResizability(.contentSize)

        MenuBarExtra("TypeCompass", systemImage: "location.north.circle") {
            SourceMenu(store: store)
        }
    }
}

private struct SourceMenu: View {
    @ObservedObject var store: InputSourceStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(L10n.format("Current: %@", store.currentName))
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
