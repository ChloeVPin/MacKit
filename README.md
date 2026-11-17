# MacKit

A native macOS app for setting up and tuning a Mac. Pick the settings you want, review them together, and apply them in one step. Every change is recorded and can be undone.

Built with Swift 6 and SwiftUI for macOS 27.

## Run it

Open `MacKit.xcodeproj` in Xcode 27 and press Run. Or build from Terminal:

```bash
xcodebuild -project MacKit.xcodeproj -scheme MacKit -derivedDataPath build build
```

```bash
open build/Build/Products/Debug/MacKit.app
```

### Try it without touching your Mac

Sample mode runs the whole app, including applying and undoing, against an in-memory Mac. No real setting is read or written.

```bash
open build/Build/Products/Debug/MacKit.app --args -sample 1
```

Other values: `-sample empty` (a factory-fresh Mac) and `-sample worst` (very long text and failed changes, for checking the layout). See `MacKit/App/SampleData.swift` for the rest.

## How it works

- **Nothing changes until you apply.** Flipping a switch marks a pending change. The review sheet lists every change, and the Terminal command behind each one if you ask for it.
- **Everything can be undone.** Before a setting is written, MacKit records its exact prior value. History puts it back.
- **Only known settings.** The catalog is a fixed list of about 400 macOS settings, each checked against the current system. MacKit never downloads or runs scripts, and it can only launch a short allowlist of system tools.
- **Administrator changes use the system prompt.** Power, sharing, login, update, and firewall settings ask macOS for a password once per batch. MacKit never sees it.

## Layout

```
MacKit/                    The app (SwiftUI)
  App/                     Entry point, app state, sample data
  DesignSystem/            Spacing, type, and shared components
  Features/                Home, settings pages, review sheet, history
Packages/MacKitCore/       The engine. No UI, fully unit tested
  Catalog/                 Every setting and quick setup, as data
  Engine/                  Reads state, plans changes, applies and undoes them
  System/                  Access to preferences and commands, plus an in-memory fake
Tools/make-icon.swift      Draws the app icon
```

Run the engine's tests:

```bash
swift test --package-path Packages/MacKitCore
```

## Status

Early. The app is unsigned, so macOS will warn on first launch of a downloaded copy. Changes that need an administrator password have been tested against the in-memory fake only, not on a real Mac.
