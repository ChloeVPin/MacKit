# Contributing

Bug reports and pull requests are welcome. Building needs macOS 27 and Xcode 27; there are no outside packages.

Read `PLAN.md` first, especially "Where things stand". It records what is built, what was tried and removed, and what is known not to work.

## Work without touching your Mac

- Run the app in sample mode. It uses an in-memory Mac and a pretend store, so nothing real changes:

  ```bash
  open build/Build/Products/Debug/MacKit.app --args -sample 1
  ```

  `-screen <category|discover|installed|history>`, `-open <setting id>`, and `-option <option>` start it in a given state. `-sample worst` and `-sample empty` show the edge cases.
- Run the tests, and add tests for what you change:

  ```bash
  swift test --package-path Packages/MacKitCore
  ```

- A few test suites are off by default because they reach the real Mac. Leave them off unless you mean it:
  - `MACKIT_LIVE=1` reads every setting from this Mac. Nothing is changed.
  - `MACKIT_LIVE_APPLY=1` flips real settings for a moment and puts them back.
  - `MACKIT_LIVE_ADMIN=1` changes root-owned settings with your password. It refuses to run outside a virtual machine unless set to `this-mac`.
- Don't test the store by installing a real app. The tests build small fake apps for that.

## Adding a setting

- Confirm the key still exists and takes effect on macOS 27.
- If the app has a folder in `~/Library/Containers`, reading its preferences triggers a macOS privacy prompt. Those go behind Full Disk Access (`Catalog.isProtected`).
- Only label a setting "Right away" when you've seen it apply live. Otherwise give the real scope, such as after logging out.
- To list every setting with its commands: `MACKIT_DUMP=<file> swift test --package-path Packages/MacKitCore --filter CatalogDumpTests`.

## Style

- Plain words in the interface. No jargon, no marketing copy.
- SwiftUI and AppKit only: system fonts, materials, and SF Symbols. No third-party UI libraries or web views.
- No screenshots or drawn pictures of settings in the app. Both were tried and removed on purpose.
