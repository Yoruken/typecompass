import Foundation

/// Shared translations for SwiftUI labels and messages produced outside views.
public enum L10n {
    // Packaged macOS apps keep resources in Contents/Resources. SwiftPM's
    // generated accessor also supports command-line and Xcode development builds.
    private static let bundle: Bundle = {
        if let url = Bundle.main.url(forResource: "TypeCompass_TypeCompassCore", withExtension: "bundle"),
           let packaged = Bundle(url: url) {
            return packaged
        }
        return .module
    }()

    public static func text(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    public static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: arguments)
    }
}
