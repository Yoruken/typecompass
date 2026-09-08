import AppKit
import SwiftUI
import TypeCompassCore

struct ContentView: View {
    @ObservedObject var store: InputSourceStore
    @State private var sample = ""
    private let detector = LanguageDetector()
    private var detection: Detection { detector.detect(sample) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 14) {
                    Image(systemName: "location.north.circle.fill")
                        .font(.system(size: 44)).foregroundStyle(.teal)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TypeCompass").font(.largeTitle.bold())
                        Text(L10n.text("Three languages. Your familiar input sources."))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(L10n.text("PROTOTYPE")).font(.caption.bold())
                        .padding(8).background(.teal.opacity(0.12), in: Capsule())
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label(L10n.text("Your input sources"), systemImage: "keyboard").font(.headline)
                            Spacer()
                            Button(L10n.text("Refresh"), systemImage: "arrow.clockwise") { store.refresh() }
                        }
                        Text(L10n.text("Enable your preferred sources in macOS Keyboard settings, then map them here."))
                            .font(.callout).foregroundStyle(.secondary)
                        ForEach(InputLanguage.allCases) { language in
                            HStack {
                                Text(language.badge).font(.title3.bold())
                                    .frame(width: 32, height: 32)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                                Picker(language.title, selection: Binding(
                                    get: { store.mappedID(for: language) },
                                    set: { store.setMapping($0, for: language) }
                                )) {
                                    Text(L10n.text("Choose input source…")).tag("")
                                    ForEach(store.sources) { source in
                                        Text(source.name).tag(source.id)
                                    }
                                }
                                Button(L10n.text("Switch")) { store.select(language) }
                                    .disabled(store.mappedID(for: language).isEmpty)
                                    .accessibilityLabel(L10n.format("Switch to %@", language.title))
                            }
                        }
                        Divider()
                        Text(L10n.format("Current: %@", store.currentName)).font(.callout.bold())
                        Text(store.status).font(.caption).foregroundStyle(.secondary)
                        Text(L10n.text("Finish choosing a candidate before switching. The menu bar also provides these controls."))
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(10)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Label(L10n.text("Detection lab"), systemImage: "text.magnifyingglass").font(.headline)
                        Text(L10n.text("Try Pinyin, Romaji or English. This starter vocabulary only analyzes the sample below."))
                            .font(.callout).foregroundStyle(.secondary)
                        TextField("nihao · ohayou · hello", text: $sample)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel(L10n.text("Language detection sample"))
                            .onChange(of: sample) { _, value in
                                if value.count > 256 { sample = String(value.prefix(256)) }
                            }
                        HStack {
                            ForEach(["nihao", "ohayou", "hello", "shi"], id: \.self) { example in
                                Button(example) { sample = example }.buttonStyle(.bordered)
                            }
                            Spacer()
                            Button(L10n.text("Clear")) { sample = "" }.disabled(sample.isEmpty)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: detection.language == nil ? "pause.circle" : "lightbulb")
                                .foregroundStyle(.teal).font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(detection.language?.title ?? L10n.text("Keep current source")).font(.headline)
                                Text(detection.explanation).font(.callout).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14).background(.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    }.padding(10)
                }

                Label(L10n.text("Local only. No global keyboard monitoring. Automatic switching is planned."), systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(28)
        }
        .frame(width: 680, height: 680)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.refresh()
        }
        .onReceive(DistributedNotificationCenter.default().publisher(
            for: Notification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged")
        )) { _ in store.refresh() }
    }
}
