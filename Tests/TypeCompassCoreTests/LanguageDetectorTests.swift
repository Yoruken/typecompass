import Testing
@testable import TypeCompassCore

@Test(arguments: ["nihao", "NIHAO", "ni hao", "xie'xie", "zhongwen"])
func pinyinHints(sample: String) {
    #expect(LanguageDetector().detect(sample).language == .pinyin)
}

@Test(arguments: ["ohayou", "konnichiwa", "arigatou", "watashi desu"])
func romajiHints(sample: String) {
    #expect(LanguageDetector().detect(sample).language == .romaji)
}

@Test(arguments: ["hello", "thank you", "hello world", "PLEASE"])
func englishHints(sample: String) {
    #expect(LanguageDetector().detect(sample).language == .english)
}

@Test(arguments: ["", "  ", "shi", "ha", "a", "ni", "sushi", "xyzxyz", "hello nihao", "你好", "こんにちは", "https://example.com", "hello123", "hello unknown", "hëllo", String(repeating: "a", count: 257)])
func abstainsOnAmbiguousUnsupportedOrMixedInput(sample: String) {
    #expect(LanguageDetector().detect(sample).language == nil)
}
