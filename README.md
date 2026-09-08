# TypeCompass

A local-first macOS companion for switching between your existing Chinese Pinyin, Japanese Romaji, and English input sources. Built with SwiftUI.

**Status: early prototype.** Input-source mapping and manual switching work through macOS Text Input Source Services. The detection lab uses a small starter vocabulary. Global detection and automatic switching are **not implemented yet**.

TypeCompass is a companion utility, not a new input method. Keep the input methods and candidate windows you already use.

## Current features

- SwiftUI window and menu bar controls.
- English and Simplified Chinese UI, following the macOS preferred app language.
- List enabled keyboard input sources and map one to each language.
- Switch mapped sources manually and inspect the result.
- Local detection lab with Pinyin, Romaji, and English examples.
- Abstain on short, unknown, mixed, or unsupported samples.
- Persist input-source preferences only; no input history, analytics, network requests, global keyboard hooks, or clipboard access.

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

## 界面语言 / Interface language

支持简体中文和英文，默认跟随 macOS 的语言偏好。也可以在 macOS 的“语言与地区”设置中，为 TypeCompass 单独选择简体中文，重新打开应用后生效。中文支持覆盖主窗口、菜单栏、输入法切换状态、错误提示和语言识别说明；输入法名称由 macOS 提供。

The interface follows your macOS preferred app language, with English as the fallback. You can choose Simplified Chinese specifically for TypeCompass in macOS Language & Region settings, then relaunch. This changes interface text only; input-source mappings and detection behavior are unchanged.

Translations live in `Sources/TypeCompassCore/Resources/{en,zh-Hans}.lproj/Localizable.strings`. Keep keys and format placeholders consistent across both files. The app build script includes the localization bundle so the packaged app works outside the source checkout.

## Detection lab

Use an English input source to enter raw Latin letters in the lab, or choose an example button. `nihao` and `ni hao` suggest Chinese, `ohayou` suggests Japanese, and `hello` suggests English. Ambiguous input such as `shi` remains undecided.

This is an explainable starter lexicon, **not a trained model, a complete Pinyin/Romaji parser, or an accuracy claim**. Unrecognized words deliberately produce no suggestion. Samples are held only in the window's memory and are not saved by TypeCompass. The lab never triggers a switch.

## Roadmap

- [ ] Pinyin syllable parsing, Romaji parsing, English word-frequency scoring, and a representative evaluation corpus.
- [ ] Explicitly opt-in keyboard observation, with clear permission handling and sensitive-field exclusion.
- [ ] Composition-aware suggestions that preserve candidate selection and respect manual switching.
- [ ] Conservative automatic switching, cooldowns, and a correction shortcut.
- [ ] Compatibility verification with Apple Pinyin, Apple Japanese, Google Japanese Input, and third-party Pinyin input methods.
- [ ] Signed, notarized releases and additional localizations.

## Architecture

- `Sources/TypeCompass`: SwiftUI UI and macOS input-source integration.
- `Sources/TypeCompassCore`: isolated, deterministic language hint logic.
- `Tests/TypeCompassCoreTests`: matching, ambiguity, normalization, and input-boundary tests.
- `scripts/build-app.sh`: reproducible local app bundle packaging.

The current prototype does not request Accessibility or Input Monitoring permission. Future global observation must be opt-in and must not log or transmit typed content.

## Contributing

Use commit messages in the form `type: description`, for example:

```text
feat: add composition-aware language suggestions
fix: preserve manual input source selection
docs: clarify local privacy behavior
```

Run `swift test` and `bash scripts/build-app.sh` before submitting changes. UI and input-source changes also need manual macOS verification; unit tests do not establish compatibility with every input method.
