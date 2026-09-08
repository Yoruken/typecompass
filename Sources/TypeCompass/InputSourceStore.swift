import AppKit
import Carbon
import Combine
import TypeCompassCore

struct InputSource: Identifiable {
    let id: String
    let name: String
    let reference: TISInputSource
}

@MainActor
final class InputSourceStore: ObservableObject {
    @Published private(set) var sources: [InputSource] = []
    @Published private(set) var currentID = ""
    @Published private(set) var status = "Select the input sources you already use."
    @Published private var mappings: [String: String]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mappings = defaults.dictionary(forKey: "inputSourceMappings") as? [String: String] ?? [:]
        refresh()
    }

    var currentName: String {
        sources.first(where: { $0.id == currentID })?.name ?? "Unavailable"
    }

    func mappedID(for language: InputLanguage) -> String {
        let id = mappings[language.rawValue] ?? ""
        return sources.contains(where: { $0.id == id }) ? id : ""
    }

    func setMapping(_ id: String, for language: InputLanguage) {
        mappings[language.rawValue] = id.isEmpty ? nil : id
        defaults.set(mappings, forKey: "inputSourceMappings")
    }

    func refresh() {
        let filter: [String: Any] = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
            kTISPropertyInputSourceIsSelectCapable as String: true,
            kTISPropertyInputSourceIsEnabled as String: true
        ]
        guard let list = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource] else {
            sources = []
            currentID = ""
            status = "Could not read enabled input sources. Try Refresh."
            return
        }
        sources = list.compactMap { source in
            guard let id = Self.stringProperty(source, kTISPropertyInputSourceID),
                  let name = Self.stringProperty(source, kTISPropertyLocalizedName) else { return nil }
            return InputSource(id: id, name: name, reference: source)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
            currentID = Self.stringProperty(current, kTISPropertyInputSourceID) ?? ""
        } else {
            currentID = ""
        }
    }

    func select(_ language: InputLanguage) {
        refresh()
        guard let source = sources.first(where: { $0.id == mappedID(for: language) }) else {
            status = "Choose an enabled input source for \(language.title) first."
            return
        }
        let result = TISSelectInputSource(source.reference)
        refresh()
        if result != noErr {
            status = "macOS could not select \(source.name) (error \(result))."
        } else if currentID == source.id {
            status = "Selected \(source.name). Existing text is unchanged."
        } else {
            status = "macOS accepted the request, but the current source has not changed. Try Refresh."
        }
    }

    private static func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
}
