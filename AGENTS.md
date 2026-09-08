# Development guidance

- Build the macOS interface with SwiftUI. This project is a companion to existing input methods, not a replacement input method.
- Keep detection local. Never persist or transmit typed content. Any future global keyboard observation must be explicitly opt-in.
- Preserve active composition and respect manual language selection. Abstain when evidence is insufficient.
- Keep experimental and unimplemented behavior clearly labeled in the UI and README.
- Use commit messages in the format `type: description` (for example, `feat: add language suggestions`).
- Run `swift test` and `bash scripts/build-app.sh` for functional changes. Verify UI and source-switching changes in the actual macOS app.
