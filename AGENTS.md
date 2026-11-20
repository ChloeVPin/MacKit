# MacKit

A native macOS setup and tweak utility: every macOS setting worth changing in one app, plus an app store built on Homebrew Cask data with its own installer. Swift 6, SwiftUI, macOS 27 only, unsigned (ad-hoc). The bar is an app people would pay for that feels like Apple made it.

Read `PLAN.md` before doing anything, especially "Where things stand". It records what is built, what was tried and removed, and what is known not to work.

## Layout

- `Packages/MacKitCore`: the engine. Catalog of about 400 settings, change planning, apply with rollback, undo, history, live-apply signals, app installer. No UI.
- `MacKit/`: the app. `App` (models), `Features` (screens), `DesignSystem` (shared components; reuse these before writing new ones).
- `Archive/`: parked work. Don't revive it unless asked.
- `Tools/`: scripts for the app icon, brand images, and the disk image. `Brand/` holds the wordmark font, `Docs/` the README images.
- `.github/workflows/`: CI on every push, and a release for every `v*` tag.

## Commands

- Build: `xcodebuild -project MacKit.xcodeproj -scheme MacKit -configuration Debug -derivedDataPath build build`
- Test: `swift test --package-path Packages/MacKitCore` (must stay green; add tests for what you change)
- Run safely: launch `build/Build/Products/Debug/MacKit.app` with `-sample 1`. That uses an in-memory fake system and a pretend store. Extras: `-screen <category|discover|installed|history>`, `-open <setting id>`, `-option <option>`. `-sample worst` and `-sample empty` show edge cases.
- List every setting with its commands: `MACKIT_DUMP=<file> swift test --package-path Packages/MacKitCore --filter CatalogDumpTests`

## Hard rules

1. Never change real settings on this Mac while working. No `defaults write`, no killing Finder or the Dock, no clicking through the app without `-sample 1`. Reading real settings is fine. `LiveApplyTests` flips real settings and only runs when `MACKIT_LIVE_APPLY` is set; don't set it without the user's say-so for that run. The same goes for `MACKIT_LIVE_ADMIN` (changes root-owned settings with the user's password) and `MACKIT_PROGRESS_URL` (downloads a real address). Never pass `-startGet` without `-sample 1`: it installs a real app.
2. Never download or install a real app to test the store. Tests use locally built fake apps.
3. No preview pictures, screenshots, or drawn illustrations of settings in the app. Tried twice, removed on purpose. Store app icons are fine.
4. Don't delete permanently. Move to the Trash and say what you moved.
5. Stay native: SwiftUI and AppKit, system fonts and materials, SF Symbols. No third-party UI libraries, no web views.
6. Plain words in the interface. No jargon, no marketing copy.
7. The folder is a git repository, published at github.com/ChloeVPin/MacKit. Don't commit or push unless asked. Pushing a `v*` tag publishes a public release. Commits carry no AI co-author lines.

## Things that bite

- Reading the preferences of an app that has a folder in `~/Library/Containers` makes macOS show an "access data from other apps" prompt and blocks the read. `Catalog.isProtected` gates those behind Full Disk Access. Check for a container before adding any app's settings.
- `UserDefaults(suiteName:)` returns nil for the global domain. Use `CFPreferences`.
- Saving a preference doesn't reach running apps. Each setting that applies live has a `LiveSignal` (`System/LiveSignals.swift`) sent after saving. Those call private system functions looked up by name; `PLAN.md` lists which were confirmed on a real Mac and which weren't.
- The app target defaults to main-actor isolation. The core package does not; mark heavy work `@concurrent`.
- A per-download `URLSession` delegate doesn't get progress with the async download call. The installer uses a session-level delegate for that reason.
- The "takes effect" label on a setting is a promise. Only say "Right away" when it's been shown to be true.

## Decisions already made

- macOS 27 only, no fallbacks.
- No Apple Developer account, so administrator changes use the system password prompt, not a privileged helper.
- The store uses Homebrew Cask's public list for data and installs apps itself. It does not run `brew`.
- Every store app shows a logo; apps with none found get a colored initial tile.
- Bundle ID `dev.mackit.MacKit` is a placeholder.
