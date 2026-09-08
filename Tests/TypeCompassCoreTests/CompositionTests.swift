import Foundation
import Testing
@testable import TypeCompassCore

private func state(_ text: String, _ caret: Int, length: Int = 0, marked: MarkedText = .none) -> TextSnapshot {
    TextSnapshot(text: text, selection: NSRange(location: caret, length: length), marked: marked)
}

@Test func refusesAnExistingSelectionOrComposition() {
    #expect(CompositionBoundary(baseline: state("old", 0, length: 3)) == nil)
    #expect(CompositionBoundary(baseline: state("old", 3, marked: .range(NSRange(location: 0, length: 3)))) == nil)
    #expect(CompositionBoundary(baseline: state("old", 4)) == nil)
}

@Test func keepsPrefixAndSuffixOutsideTheTransaction() throws {
    let boundary = try #require(CompositionBoundary(baseline: state("before|after", 7)))
    let current = state("before|helloafter", 12)
    #expect(boundary.insertion(in: current) == NSRange(location: 7, length: 5))
    #expect(boundary.canRewrite(current, requiresMarkedText: false))
    #expect(boundary.insertion(in: state("BEFORE|helloafter", 12)) == nil)
    #expect(boundary.insertion(in: state("before|helloAFTER", 12)) == nil)
    #expect(boundary.insertion(in: state("before|helloafter", 2)) == nil)
    #expect(boundary.insertion(in: state("before|helloafter", 12, length: 1)) == nil)
}

@Test func compositionLengthIsNotTheNumberOfRawKeys() throws {
    let boundary = try #require(CompositionBoundary(baseline: state("前😀", 3)))
    let range = NSRange(location: 3, length: 3)
    let japanese = state("前😀おはよ", 6, marked: .range(range))
    #expect(boundary.insertion(in: japanese) == range)
    #expect(boundary.canRewrite(japanese, requiresMarkedText: true))
    #expect(!boundary.canRewrite(state("前😀おはよ", 6, marked: .unavailable), requiresMarkedText: true))
    #expect(!boundary.canRewrite(state("前😀おはよ", 6), requiresMarkedText: true))
}

@Test func refusesMarkedTextThatIncludesEarlierCharacters() throws {
    let boundary = try #require(CompositionBoundary(baseline: state("old", 3)))
    #expect(!boundary.canRewrite(state("oldhello", 8, marked: .range(NSRange(location: 0, length: 8))), requiresMarkedText: true))
    #expect(!boundary.canRewrite(state("oldhello", 8, marked: .range(NSRange(location: 4, length: 4))), requiresMarkedText: true))
}

@Test func verifiesClearingBeforeSwitching() throws {
    let boundary = try #require(CompositionBoundary(baseline: state("keep", 4)))
    #expect(boundary.isCleared(state("keep", 4), requiresMarkedText: true))
    #expect(!boundary.isCleared(state("keepx", 5), requiresMarkedText: true))
    #expect(!boundary.isCleared(state("keep", 3), requiresMarkedText: true))
    #expect(!boundary.isCleared(state("keep", 4, marked: .unavailable), requiresMarkedText: true))
    #expect(!boundary.isCleared(state("keep", 4, marked: .range(NSRange(location: 4, length: 1))), requiresMarkedText: false))
    #expect(boundary.isCleared(state("keep", 4, marked: .unavailable), requiresMarkedText: false))
    #expect(!boundary.canRewrite(state("keep", 4), requiresMarkedText: false))
}

@Test func rejectsOversizedOrInvalidChanges() throws {
    let boundary = try #require(CompositionBoundary(baseline: state("keep", 4)))
    #expect(boundary.insertion(in: state("kee", 3)) == nil)
    #expect(boundary.insertion(in: state("keep" + String(repeating: "x", count: 513), 517)) == nil)
    #expect(boundary.insertion(in: state("keepx", 4, length: 2)) == nil)
    #expect(boundary.insertion(in: state("keepx", 4, length: -1)) == nil)
}

@Test func preservesReplayCaseAndRejectsNonletters() throws {
    #expect(try #require(RawKeystroke(keyCode: 4, shifted: false)).character == "h")
    #expect(try #require(RawKeystroke(keyCode: 4, shifted: true)).character == "H")
    #expect(try #require(RawKeystroke(keyCode: 39, shifted: false)).character == "'")
    #expect(RawKeystroke(keyCode: 39, shifted: true) == nil)
    #expect(RawKeystroke(keyCode: 36, shifted: false) == nil)
    #expect(RawKeystroke(keyCode: 49, shifted: false) == nil)
}
