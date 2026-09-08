import Foundation

public enum InputLanguage: String, CaseIterable, Identifiable, Sendable {
    case pinyin, romaji, english
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .pinyin: L10n.text("中文 · Pinyin")
        case .romaji: L10n.text("日本語 · Romaji")
        case .english: L10n.text("English")
        }
    }
    public var badge: String {
        switch self {
        case .pinyin: "中"
        case .romaji: "あ"
        case .english: "A"
        }
    }
}

public struct Detection: Equatable, Sendable {
    public let language: InputLanguage?
    public let explanation: String
}

/// A deliberately small, deterministic lexicon for the initial detection lab.
/// These matches are hints, not calibrated confidence or a production classifier.
public struct LanguageDetector: Sendable {
    public init() {}

    private static let lexicons: [InputLanguage: Set<String>] = [
        .pinyin: Set("nihao xiexie zaijian zhongwen zhongguo pengyou jintian mingtian xianzai shenme weishenme keyi meiyou wo women nimen shijie gongzuo xihuan".split(separator: " ").map(String.init)),
        .romaji: Set("ohayou ohayo konnichiwa konbanwa arigatou arigato sayounara sayonara nihongo watashi watashitachi anata desu masu sumimasen onegaishimasu kudasai kawaii sugoi genki ashita".split(separator: " ").map(String.init)),
        .english: Set("hello thanks thank you goodbye please morning evening today tomorrow world meeting work email the this that these those with from would could should have will your what when where why how english quick brown fox jumps over lazy dog".split(separator: " ").map(String.init))
    ]

    public func detect(_ text: String) -> Detection {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else {
            return Detection(language: nil, explanation: L10n.text("Type a sample to explore a language hint."))
        }
        guard value.count <= 256 else {
            return Detection(language: nil, explanation: L10n.text("Use a sample of 256 characters or fewer."))
        }
        guard value.unicodeScalars.allSatisfy({
            (97...122).contains($0.value) || CharacterSet.whitespacesAndNewlines.contains($0) || $0 == "'"
        }) else {
            return Detection(language: nil, explanation: L10n.text("This prototype accepts unaccented Latin letters, spaces and apostrophes."))
        }
        let tokens = value.split { $0.isWhitespace || $0 == "'" }.map(String.init)
        let joined = tokens.joined()
        guard joined.count >= 4 else {
            return Detection(language: nil, explanation: L10n.text("Too little context. Keep the current input source."))
        }
        let matches = InputLanguage.allCases.filter { language in
            let words = Self.lexicons[language, default: []]
            return words.contains(joined) || (!tokens.isEmpty && tokens.allSatisfy(words.contains))
        }
        guard matches.count == 1, let language = matches.first else {
            return Detection(language: nil, explanation: L10n.text("Ambiguous or outside the starter vocabulary. Keep the current input source."))
        }
        return Detection(language: language, explanation: L10n.text("Matched the starter vocabulary. This is a hint, not a certainty."))
    }
}
