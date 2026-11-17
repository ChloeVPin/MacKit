import AppKit
import MacKitCore

/// Runs the app against an in-memory Mac instead of the real one.
///
/// Launch with `-sample 1` to explore every flow, including applying and
/// reverting, without changing a single real setting. Other arguments put
/// the window in a specific state, which is how screens are checked:
///
///     -sample 1 -screen finder -change 3 -open finder.hidden-files
///     -sample worst            (longest names, most changes, failures)
///     -sample empty            (a factory-fresh Mac with no history)
enum SampleData {
    static func modelForLaunch() -> AppModel? {
        let defaults = UserDefaults.standard
        guard let mode = defaults.string(forKey: "sample") else { return nil }

        let home = URL(filePath: "/Users/sample")
        let system = InMemorySystem()
        var access = system.access(home: home)
        // `-fda NO` shows how protected apps' settings look before the user
        // grants Full Disk Access.
        if defaults.string(forKey: "fda") == "NO" { access.hasFullDiskAccess = { false } }
        var tweaks = Catalog.tweaks(home: home)
        if mode == "worst" { tweaks = worstCase(tweaks) }

        // A lived-in Mac: some settings already differ from stock.
        let preset: [(PreferenceDomain, String, PreferenceValue)] = [
            (.app("com.apple.finder"), "AppleShowAllFiles", .bool(true)),
            (.app("com.apple.finder"), "ShowPathbar", .bool(true)),
            (.app("com.apple.finder"), "FXPreferredViewStyle", .string("Nlsv")),
            (.global, "AppleShowAllExtensions", .bool(true)),
            (.app("com.apple.dock"), "autohide", .bool(true)),
            (.app("com.apple.dock"), "autohide-delay", .double(0.2)),
            (.app("com.apple.dock"), "show-recents", .bool(false)),
            (.app("com.apple.screencapture"), "type", .string("jpg")),
            (.global, "NSAutomaticSpellingCorrectionEnabled", .bool(false)),
            (.global, "NSAutomaticDashSubstitutionEnabled", .bool(false)),
            (.global, "NSNavPanelExpandedStateForSaveMode", .bool(true)),
            (.global, "NSNavPanelExpandedStateForSaveMode2", .bool(true)),
        ]
        // "empty" is a factory-fresh Mac with no history.
        for (domain, key, value) in preset where mode != "empty" {
            try? system.set(value, for: key, in: domain)
        }
        if mode == "worst" {
            // Fail some writes so the error states can be seen.
            system.failWrites(to: "ShowStatusBar")
            system.failAuthorization(with: .authorizationCancelled)
        }

        let model = AppModel(
            tweaks: tweaks,
            engine: TweakEngine(system: access),
            historyStore: nil,
            history: mode == "empty" ? [] : sampleHistory(tweaks: tweaks),
            store: StoreModel(backend: SampleStoreBackend(fails: mode == "worst"))
        )

        switch defaults.string(forKey: "screen") {
        case "history": model.destination = .history
        case "discover": model.destination = .discover
        case "installed": model.destination = .installed
        case let name?:
            if let category = TweakCategory(rawValue: name) { model.destination = .category(category) }
        case nil: break
        }

        if let appearance = defaults.string(forKey: "appearance") {
            Task { NSApplication.shared.appearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua) }
        }

        let changeCount = mode == "worst" ? tweaks.count : defaults.integer(forKey: "change")
        Task {
            await model.load()
            // "-size 820x540" checks the layout at a given window size.
            if let size = defaults.string(forKey: "size")?.split(separator: "x").compactMap({ Double($0) }), size.count == 2,
               let window = NSApplication.shared.windows.first(where: \.isVisible) {
                window.setContentSize(NSSize(width: size[0], height: size[1]))
            }
            // Change the first few settings on the screen being shown.
            let visible = model.destination.category.map(model.tweaks(in:)) ?? tweaks
            for tweak in (visible + tweaks).prefix(changeCount) {
                let current = model.state(of: tweak).optionID
                if let other = tweak.options.last(where: { $0.id != current }) {
                    model.select(other.id, for: tweak, staged: true)
                }
            }
            if let id = defaults.string(forKey: "setup"), let setup = QuickSetup.all.first(where: { $0.id == id }) {
                model.toggle(setup)
            }
            if let id = defaults.string(forKey: "open"), let tweak = model.tweak(id) {
                model.open(tweak)
                // "-instant YES" changes the setting the way a click would.
                if let option = defaults.string(forKey: "option") {
                    model.select(option, for: tweak, staged: !defaults.bool(forKey: "instant"))
                }
            }
            // "-app <id>" opens an app's page; "-get <id>" starts installing
            // it; "-shelf <category>" picks a category on Discover.
            if model.destination.isStore { await model.store.loadIfNeeded() }
            if let shelf = defaults.string(forKey: "shelf") { model.store.category = StoreCategory(rawValue: shelf) }
            if let id = defaults.string(forKey: "app") { model.store.openAppID = id }
            if let id = defaults.string(forKey: "get"), let app = model.store.app(id) { model.store.install(app) }
            if let query = defaults.string(forKey: "search") {
                model.searchText = query
            }
            if defaults.bool(forKey: "review") {
                model.beginReview()
                if defaults.bool(forKey: "run") { await model.runReview() }
            }
            #if DEBUG
            if let snapshotPath = defaults.string(forKey: "snapshot") {
                let wait = defaults.object(forKey: "snapshotDelay") != nil ? defaults.double(forKey: "snapshotDelay") : 0.45
                try? await Task.sleep(for: .seconds(wait))
                if let window = NSApplication.shared.windows.last(where: \.isVisible),
                   let root = window.contentView?.superview ?? window.contentView,
                   let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds) {
                    root.cacheDisplay(in: root.bounds, to: bitmap)
                    if let png = bitmap.representation(using: .png, properties: [:]) {
                        try? png.write(to: URL(filePath: snapshotPath), options: .atomic)
                    }
                }
                exit(0)
            }
            #endif
        }
        return model
    }

    /// History whose snapshots are real, so reverting a sample entry works.
    private static func sampleHistory(tweaks: [Tweak]) -> [HistoryRecord] {
        func entry(_ id: String, from: String, to: String, reverted: Bool = false) -> HistoryEntry? {
            guard let tweak = tweaks.first(where: { $0.id == id }),
                  case .preferences(let bindings) = tweak.mechanism,
                  let fromLabel = tweak.option(from)?.label, let toLabel = tweak.option(to)?.label
            else { return nil }
            return HistoryEntry(
                tweakID: id, title: tweak.title, category: tweak.category, section: tweak.section, from: fromLabel, to: toLabel,
                snapshot: .preferences(bindings.map {
                    // A setting that was stock before had no key stored at all.
                    PreferenceSnapshot(domain: $0.domain, path: $0.path, key: $0.key, value: from == tweak.stockOptionID ? nil : $0.values[from])
                }),
                revertedAt: reverted ? .now.addingTimeInterval(-3000) : nil
            )
        }
        let now = Date.now
        return [
            HistoryRecord(date: now.addingTimeInterval(-60 * 42), entries: [
                entry("finder.hidden-files", from: "off", to: "on"),
                entry("finder.path-bar", from: "off", to: "on"),
                entry("dock.recents", from: "on", to: "off"),
            ].compactMap(\.self)),
            HistoryRecord(date: now.addingTimeInterval(-60 * 60 * 26), entries: [
                entry("screenshot.format", from: "png", to: "jpg"),
                entry("text.autocorrect", from: "on", to: "off"),
                entry("text.smart-quotes", from: "on", to: "off", reverted: true),
            ].compactMap(\.self)),
            HistoryRecord(date: now.addingTimeInterval(-60 * 60 * 24 * 9), entries: [
                entry("dock.autohide", from: "off", to: "on"),
            ].compactMap(\.self)),
        ]
    }

    /// Stretches every string, to see what breaks.
    private static func worstCase(_ tweaks: [Tweak]) -> [Tweak] {
        tweaks.enumerated().map { index, tweak in
            guard index % 3 == 0 else { return tweak }
            return Tweak(
                id: tweak.id,
                title: tweak.title + " in every window, on every display, for every user of this Mac",
                summary: tweak.summary + " " + String(repeating: "This sentence exists only to make the summary far longer than any real one would be. ", count: 2),
                category: tweak.category,
                section: tweak.section,
                options: tweak.options.map { TweakOption($0.id, $0.label + (tweak.isToggle ? "" : " (an unusually long option name)")) },
                stock: tweak.stockOptionID,
                mechanism: tweak.mechanism,
                effect: tweak.effect,
                caution: tweak.caution,
                input: tweak.input,
                hasDefault: tweak.hasDefault,
                requiresBattery: tweak.requiresBattery
            )
        }
    }
}
