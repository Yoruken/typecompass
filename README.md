# TypeCompass

A local-first macOS companion for switching between your existing Chinese Pinyin, Japanese Romaji, and English input sources. Built with SwiftUI.

**Status: experimental prototype.** Includes opt-in live keyboard observation, a non-activating language suggestion panel, and a confirmation shortcut that clears the current segment, switches the input source, and replays the original keys. Detection still uses a small starter vocabulary. Cross-app IME compatibility requires on-device verification; passing unit tests does not establish that a particular app supports retyping.

TypeCompass is a companion utility, not a new input method. Keep the input methods and candidate windows you already use.

## Current features

- SwiftUI window and menu bar controls.
- English and Simplified Chinese UI, following the macOS preferred app language.
- List enabled keyboard input sources and map one to each language.
- Switch mapped sources manually and inspect the result.
- Local detection lab with Pinyin, Romaji, and English examples.
- Abstain on short, unknown, mixed, or unsupported samples.
- Opt-in live suggestions while typing in other apps, using raw keys and accessible text-field state.
- **Control + Option + Return (`⌃⌥↩`)** confirms a suggested correction. No unattended switching.
- Verify the current field, input source, composition range, and surrounding text before deleting or replaying.
- Persist input-source preferences only; no input history, analytics, network requests, or automatic clipboard access.

## Build and run

Requires macOS 14 or later and Xcode 16 or later with Swift 6. No third-party dependencies.

```sh
git clone https://github.com/Yoruken/typecompass.git
cd typecompass
swift test
bash scripts/build-app.sh
open build/TypeCompass.app
```

For development, open `Package.swift` in Xcode and select the TypeCompass executable scheme. The build script creates a locally ad-hoc-signed app for the host architecture. It does not produce a notarized distribution release.

Enable your preferred input sources in **System Settings → Keyboard → Text Input → Edit**, then choose them in TypeCompass. Choose a Pinyin mode for Chinese and a Romaji-configured Japanese mode. The utility selects existing sources; it does not change their internal typing settings.

Finish any active candidate selection before manually switching. Switching does not rewrite text already entered, and macOS per-document input-source settings can affect the source selected when focus changes.

## 实时辅助 / Live assistance

1. 在 TypeCompass 中为中文、日语和英语分别指定不同的输入法。
2. 点击“允许辅助功能”和“允许输入监控”，在 macOS 中给 **TypeCompass** 开启对应权限。返回应用点击“刷新”；如果 macOS 要求，请重新打开应用。
3. 主动开启“实时输入辅助”。每次启动默认关闭，不会自动开始监听。
4. 在另一个应用的普通文本输入框中开始新一轮输入。例如，在简体拼音下输入 `hello`，或在 ABC 下输入 `nihao`。输入过程中暂不按空格或回车选词。
5. 出现语言建议后，按 **Control + Option + Return**。若输入框提供了可核对的范围，应用会清除本轮内容、切换输入法，再重放原始按键。之后按原来的方式选词。

“清除”只针对开启监听后跟踪的本轮输入，**不会全选整个输入框**。如果提示输入框不支持，快捷键不会执行删除；如果流程中断，打开 TypeCompass 查看“原始输入”，核对目标输入框后手动恢复。

Enable Accessibility and Input Monitoring for TypeCompass, then turn on Live input assistance. Start a fresh segment in another app. A hint appears above the caret when the starter detector recognizes a different language. The panel does not take keyboard focus. Press Control + Option + Return to confirm; candidate selection remains with your existing IME.

### Compatibility and limits

- macOS does not expose every input method's candidate window through a universal external API. TypeCompass tracks QWERTY letter keys and checks the focused field's accessible value and selection. It optionally reads `AXTextInputMarkedRange` when the client provides it; this attribute is **not universally supported**.
- For Pinyin/Japanese source input, automatic clearing is refused unless the marked range exactly matches the tracked insertion. For English source input, the inserted text must exactly match the raw letters. Unsupported fields receive no destructive fallback.
- Password fields, Secure Event Input, inaccessible fields, large fields over 16,384 UTF-16 units, pre-existing selections, and pre-existing compositions are excluded. Start observing before the first letter.
- Initial support is QWERTY letters and apostrophes with Caps Lock off, at most 64 raw keys. Space, Return, Tab, candidate-number keys, navigation, shortcuts, mouse clicks, scrolling, source/focus changes, or an eight-second pause end the tracked segment. Candidate navigation is not replayed.
- Backspace while using a CJK source also ends tracking: one deleted kana or syllable is not necessarily one raw Roman key. English Backspace can update the tracked segment directly.
- New typing or focus/source changes during correction stop subsequent actions. The original raw input remains in the app for manual recovery if clearing or replay fails; inspect the field before re-entering it to avoid duplicates.
- Clearing first asks an active IME to cancel with Escape. Any remaining deletion happens one Backspace at a time, checking the field after each event. If the IME commits or changes the composition in an unsupported way, the operation stops.
- Use a scratch document first. Native editors, browsers, Electron apps, and individual IMEs can expose different accessibility state. No cross-app compatibility matrix has been accepted yet.
- Ad-hoc-signed development rebuilds may require granting macOS permissions again. This is not yet a signed/notarized distribution release.

### Privacy

Observation starts only when explicitly enabled and can be paused from the menu bar. The current raw segment and a bounded text-field snapshot are held in memory to verify edits, then discarded at a segment boundary or when observation stops. Interrupted-operation recovery text is retained in memory until cleared or the app quits. Typed content is never written to logs, stored on disk, sent to a model, or uploaded. Detection uses local rules only.

## 界面语言 / Interface language

支持简体中文和英文，默认跟随 macOS 的语言偏好。也可以在 macOS 的“语言与地区”设置中，为 TypeCompass 单独选择简体中文，重新打开应用后生效。中文支持覆盖主窗口、菜单栏、输入法切换状态、错误提示和语言识别说明；输入法名称由 macOS 提供。

The interface follows your macOS preferred app language, with English as the fallback. You can choose Simplified Chinese specifically for TypeCompass in macOS Language & Region settings, then relaunch. This changes interface text only; input-source mappings and detection behavior are unchanged.

Translations live in `Sources/TypeCompassCore/Resources/{en,zh-Hans}.lproj/Localizable.strings`. Keep keys and format placeholders consistent across both files. The app build script includes the localization bundle so the packaged app works outside the source checkout.

## Detection lab

Use an English input source to enter raw Latin letters in the lab, or choose an example button. `nihao` and `ni hao` suggest Chinese, `ohayou` suggests Japanese, and `hello` suggests English. Ambiguous input such as `shi` remains undecided.

This is an explainable starter lexicon, **not a trained model, a complete Pinyin/Romaji parser, or an accuracy claim**. Unrecognized words deliberately produce no suggestion. Samples are held only in the window's memory and are not saved by TypeCompass. The lab never triggers a switch.

## Roadmap

- [ ] Pinyin syllable parsing, Romaji parsing, English word-frequency scoring, and a representative evaluation corpus.
- [x] Explicitly opt-in keyboard observation and permission controls.
- [x] Non-activating suggestions and a guarded clear/switch/retype shortcut.
- [ ] Expand composition compatibility based on verified app/IME combinations.
- [ ] Compatibility verification with Apple Pinyin, Apple Japanese, Google Japanese Input, and third-party Pinyin input methods.
- [ ] Signed, notarized releases and additional localizations.

## Architecture

- `Sources/TypeCompass`: SwiftUI UI, input sources, AX text access, event observation, and guarded replay.
- `Sources/TypeCompassCore`: deterministic language hints, raw-key mapping, and UTF-16 insertion-boundary validation.
- `Tests/TypeCompassCoreTests`: detection, ambiguity, preservation of surrounding text, marked-range requirements, clearing checks, and key mapping.
- `scripts/build-app.sh`: reproducible local app bundle packaging.

Accessibility and Input Monitoring are needed only for opt-in live assistance. Manual input-source controls and the detection lab work without them.

## Contributing

Use commit messages in the form `type: description`, for example:

```text
feat: add composition-aware language suggestions
fix: preserve manual input source selection
docs: clarify local privacy behavior
```

Run `swift test` and `bash scripts/build-app.sh` before submitting changes. UI and input-source changes also need manual macOS verification; unit tests do not establish compatibility with every input method.
