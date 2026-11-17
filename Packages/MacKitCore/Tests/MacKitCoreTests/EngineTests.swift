import Foundation
import Testing
@testable import MacKitCore

private let home = URL(filePath: "/Users/sample")

private func makeEngine() -> (TweakEngine, InMemorySystem) {
    let system = InMemorySystem()
    return (TweakEngine(system: system.access(home: home)), system)
}

private func tweak(_ id: String) -> Tweak {
    Catalog.tweaks(home: home).first { $0.id == id }!
}

@Suite struct CatalogTests {
    @Test func `ids are unique`() {
        let ids = Catalog.tweaks(home: home).map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func `every probe example matches its own option`() {
        for tweak in Catalog.tweaks(home: home) {
            guard case .privileged(let setting) = tweak.mechanism else { continue }
            for match in setting.probe.matches {
                let output = CommandOutput(exitCode: 0, standardOutput: match.example, standardError: "")
                #expect(setting.probe.option(for: output) == match.option, "\(tweak.id): \(match.option)")
            }
        }
    }

    @Test func `every setting reads as stock on a fresh system`() async {
        let (engine, _) = makeEngine()
        for tweak in Catalog.tweaks(home: home) {
            guard tweak.hasDefault else { continue }
            #expect(await engine.state(of: tweak) == .option(tweak.stockOptionID), "\(tweak.id)")
        }
    }

    @Test func `entered values round trip through apply`() async {
        let (engine, _) = makeEngine()
        for tweak in Catalog.tweaks(home: home) {
            let value: PreferenceValue
            switch tweak.input {
            case .number(let number)?:
                let middle = number.snapped((number.range.lowerBound + number.range.upperBound) / 2 + number.step)
                value = number.isInteger ? .int(Int(middle)) : .double(middle)
            case .text?:
                value = .string("Kitchen Mac's \"test\" & more")
            case nil:
                continue
            }
            let id = tweak.optionID(for: value)
            _ = await engine.apply(engine.plan([(tweak, id)]))
            #expect(await engine.state(of: tweak) == .option(id), "\(tweak.id)")
            #expect(tweak.entry(id).map { $0.matches(value) } ?? true, "\(tweak.id)")
        }
    }

    @Test func `a slider value that equals the default is the default option`() {
        let size = tweak("dock.size")
        #expect(size.optionID(for: .int(48)) == size.stockOptionID)
        #expect(size.label(for: size.optionID(for: .int(72))) == "72")
        #expect(tweak("appearance.glass-tint").label(for: "=0.35") == "35%")
    }

    @Test func `every option round trips through apply`() async {
        let (engine, _) = makeEngine()
        for tweak in Catalog.tweaks(home: home) {
            for option in tweak.options where option.id != tweak.stockOptionID {
                _ = await engine.apply(engine.plan([(tweak, option.id)]))
                #expect(await engine.state(of: tweak) == .option(option.id), "\(tweak.id): \(option.id)")
            }
            guard tweak.hasDefault else { continue }
            _ = await engine.apply(engine.plan([(tweak, tweak.stockOptionID)]))
            #expect(await engine.state(of: tweak) == .option(tweak.stockOptionID), "\(tweak.id): back to stock")
        }
    }

    @Test func `only small, safe settings apply instantly`() {
        let all = Catalog.tweaks(home: home)
        for tweak in all where tweak.appliesInstantly {
            #expect(!tweak.requiresAdministrator && tweak.caution == nil && tweak.effect != .restarts(.finder), "\(tweak.id)")
        }
        #expect(tweak("dock.autohide").appliesInstantly)
        #expect(tweak("dock.size").appliesInstantly)
        #expect(!tweak("finder.hidden-files").appliesInstantly)
        #expect(!tweak("security.firewall").appliesInstantly)
        #expect(!tweak("finder.trash-warning").appliesInstantly)
        #expect(!tweak("screenshot.name").appliesInstantly)
        print("INSTANT \(all.count { $0.appliesInstantly }) of \(all.count)")
    }

    @Test func `every category has tweaks`() {
        let categories = Set(Catalog.tweaks(home: home).map(\.category))
        #expect(categories == Set(TweakCategory.allCases))
    }

    @Test func `every privileged option has commands`() {
        for tweak in Catalog.tweaks(home: home) {
            guard case .privileged(let setting) = tweak.mechanism else { continue }
            for option in tweak.options {
                #expect(setting.commands[option.id]?.isEmpty == false, "\(tweak.id) option \(option.id)")
            }
        }
    }

    @Test func `preference bindings only name real options`() {
        for tweak in Catalog.tweaks(home: home) {
            guard case .preferences(let bindings) = tweak.mechanism else { continue }
            let optionIDs = Set(tweak.options.map(\.id))
            for binding in bindings {
                #expect(Set(binding.values.keys).isSubset(of: optionIDs), "\(tweak.id) \(binding.key)")
                #expect(binding.ignoredWhenReading.isSubset(of: optionIDs), "\(tweak.id) \(binding.key)")
            }
        }
    }

    @Test func `only verified settings promise immediate effect`() {
        let verifiedLiveSignals: Set<Tweak.ID> = [
            "appearance.mode", "appearance.accent", "appearance.glass-tint", "appearance.wallpaper-tint",
            "windows.scroll-bars", "menubar.autohide", "keyboard.navigation", "access.pointer-size",
        ]
        let onDemandDomains: Set<String> = [
            "com.apple.archiveutility", "com.apple.CrashReporter", "com.apple.TimeMachine", "com.apple.ImageCapture",
            "/Library/Preferences/com.apple.SoftwareUpdate", "/Library/Preferences/com.apple.commerce",
        ]
        for tweak in Catalog.tweaks(home: home) where tweak.effect == .immediate {
            guard case .preferences(let bindings) = tweak.mechanism else { continue }
            let allowed = verifiedLiveSignals.contains(tweak.id)
                || bindings.allSatisfy { onDemandDomains.contains($0.domain.commandLineName) }
            #expect(allowed, "\(tweak.id) claims immediate effect without verification")
        }
    }

    @Test func `every tweak belongs to a named section`() {
        for tweak in Catalog.tweaks(home: home) {
            #expect(!tweak.section.isEmpty, "\(tweak.id)")
        }
    }

    @Test func `sections are contiguous within a category`() {
        // The interface groups consecutive tweaks, so a section split in two
        // would show up as two groups with the same name.
        for category in TweakCategory.allCases {
            let sections = Catalog.tweaks(home: home).filter { $0.category == category }.map(\.section)
            var seen: [String] = []
            for section in sections where seen.last != section {
                #expect(!seen.contains(section), "\(category.rawValue): \(section) appears twice")
                seen.append(section)
            }
        }
    }

    @Test func `quick setups only name real tweaks and options`() {
        let tweaks = Dictionary(uniqueKeysWithValues: Catalog.tweaks(home: home).map { ($0.id, $0) })
        for setup in QuickSetup.all {
            #expect(!setup.selections.isEmpty)
            #expect(Set(setup.selections.map(\.tweakID)).count == setup.selections.count, "\(setup.id) repeats a tweak")
            for selection in setup.selections {
                let tweak = tweaks[selection.tweakID]
                #expect(tweak?.option(selection.option) != nil, "\(setup.id): \(selection.tweakID) → \(selection.option)")
                #expect(tweak?.requiresAdministrator == false, "\(setup.id) must not need a password")
            }
        }
    }

    @Test func `a fresh system reads as stock for every tweak`() async {
        let (engine, system) = makeEngine()
        let tweaks = Catalog.tweaks(home: home)
        let states = await engine.states(of: tweaks)
        for tweak in tweaks where tweak.hasDefault {
            #expect(states[tweak.id] == .option(tweak.stockOptionID), "\(tweak.id)")
        }
        // Shared probe commands like `pmset -g custom` must only run once per batch.
        #expect(Set(system.commandsRun).count == system.commandsRun.count)
    }

    @Test func `applying any option reads back as that option`() async {
        for tweak in Catalog.tweaks(home: home) {
            for option in tweak.options {
                let (engine, _) = makeEngine()
                let results = await engine.apply(engine.plan([(tweak, option.id)]))
                #expect(results.map(\.outcome) == [.applied], "\(tweak.id) → \(option.id)")
                #expect(await engine.state(of: tweak) == .option(option.id), "\(tweak.id) → \(option.id)")
            }
        }
    }
}

@Suite struct StateTests {
    @Test func `integer one is read as a true boolean`() async {
        let (engine, system) = makeEngine()
        try? system.set(.int(1), for: "AppleShowAllFiles", in: .app("com.apple.finder"))
        #expect(await engine.state(of: tweak("finder.hidden-files")) == .option("on"))
    }

    @Test func `a value outside the options is custom`() async {
        let (engine, system) = makeEngine()
        try? system.set(.double(0.2), for: "autohide-delay", in: .app("com.apple.dock"))
        #expect(await engine.state(of: tweak("dock.reveal-speed")) == .custom("0.2, not set"))
    }

    @Test func `multi key tweaks match on every key`() async {
        let (engine, system) = makeEngine()
        try? system.set(.int(0), for: "autohide-delay", in: .app("com.apple.dock"))
        try? system.set(.int(0), for: "autohide-time-modifier", in: .app("com.apple.dock"))
        #expect(await engine.state(of: tweak("dock.reveal-speed")) == .option("instant"))
    }

    @Test func `inverted keys read correctly`() async {
        let (engine, system) = makeEngine()
        try? system.set(.bool(true), for: "disable-shadow", in: .app("com.apple.screencapture"))
        #expect(await engine.state(of: tweak("screenshot.shadow")) == .option("off"))
    }

    @Test func `companion keys read when only one device or panel key is set`() async {
        let (engine, system) = makeEngine()
        // AppKit sets the primary save-panel key without its legacy twin.
        try? system.set(.bool(true), for: "NSNavPanelExpandedStateForSaveMode", in: .global)
        #expect(await engine.state(of: tweak("windows.save-expanded")) == .option("on"))

        // Conflicting companion keys still report a custom state.
        try? system.set(.bool(false), for: "NSNavPanelExpandedStateForSaveMode2", in: .global)
        #expect(await engine.state(of: tweak("windows.save-expanded")) == .custom("true, false"))

        // Laptop with no Bluetooth trackpad paired.
        try? system.set(.bool(true), for: "Clicking", in: .app("com.apple.AppleMultitouchTrackpad"))
        #expect(await engine.state(of: tweak("trackpad.tap-to-click")) == .option("on"))

        try? system.set(.bool(false), for: "TrackpadRightClick", in: .app("com.apple.AppleMultitouchTrackpad"))
        #expect(await engine.state(of: tweak("trackpad.secondary-click")) == .option("off"))
    }

    @Test func `auto appearance at night and disabled scroll zoom still read cleanly`() async {
        let (engine, system) = makeEngine()
        // At night in Automatic mode, macOS sets both Dark and Auto.
        try? system.set(.string("Dark"), for: "AppleInterfaceStyle", in: .global)
        try? system.set(.bool(true), for: "AppleInterfaceStyleSwitchesAutomatically", in: .global)
        #expect(await engine.state(of: tweak("appearance.mode")) == .option("auto"))

        // Switching back to Light in System Settings leaves Auto as false.
        try? system.set(nil, for: "AppleInterfaceStyle", in: .global)
        try? system.set(.bool(false), for: "AppleInterfaceStyleSwitchesAutomatically", in: .global)
        #expect(await engine.state(of: tweak("appearance.mode")) == .option("light"))

        // Turning Scroll Zoom off in System Settings leaves the earlier key mask behind.
        try? system.set(.bool(false), for: "closeViewScrollWheelToggle", in: .app("com.apple.universalaccess"))
        try? system.set(.int(524_288), for: "HIDScrollZoomModifierMask", in: .app("com.apple.universalaccess"))
        #expect(await engine.state(of: tweak("access.scroll-zoom")) == .option("off"))
    }

    @Test func `nested dictionary settings preserve sibling keys and format PlistBuddy commands`() async throws {
        let initial: [String: Any] = [
            "IconViewSettings": [
                "iconSize": 64,
                "gridSpacing": 54,
                "viewOptionsVersion": 1,
            ]
        ]
        let updated = SystemPreferenceStore.updating(initial, along: ["IconViewSettings"][...], key: "iconSize", to: .int(96))
        let inner = try #require(updated["IconViewSettings"] as? [String: Any])
        #expect(inner["iconSize"] as? Int == 96)
        #expect(inner["gridSpacing"] as? Int == 54)
        #expect(inner["viewOptionsVersion"] as? Int == 1)

        // Removing the sole key in a fresh nested dictionary cleans up empty wrappers.
        let cleaned = SystemPreferenceStore.updating(
            ["IconViewSettings": ["iconSize": 96]], along: ["IconViewSettings"][...], key: "iconSize", to: nil
        )
        #expect(cleaned.isEmpty)

        let (engine, _) = makeEngine()
        let iconSize = tweak("desktop.icon-size")
        let plan = engine.plan([(iconSize, iconSize.optionID(for: .int(96)))])
        #expect(plan.changes[0].operations[0].commandText ==
            "/usr/libexec/PlistBuddy -c 'Set :DesktopViewSettings:IconViewSettings:iconSize 96' ~/Library/Preferences/com.apple.finder.plist")
    }

    @Test func `all eight DesktopViewSettings tweaks apply and undo without touching sibling keys`() async throws {
        let (engine, system) = makeEngine()
        let finder = PreferenceDomain.app("com.apple.finder")

        // Seed realistic Finder DesktopViewSettings from a real PropertyList
        // with sibling keys at both levels plus `iconSize` = 80 (<integer>).
        let plistXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>WindowState</key>
          <dict><key>ShowSidebar</key><true/></dict>
          <key>IconViewSettings</key>
          <dict>
            <key>viewOptionsVersion</key><integer>1</integer>
            <key>backgroundType</key><integer>0</integer>
            <key>backgroundColorRed</key><real>1.0</real>
            <key>backgroundColorGreen</key><real>1.0</real>
            <key>backgroundColorBlue</key><real>1.0</real>
            <key>gridOffsetX</key><integer>0</integer>
            <key>gridOffsetY</key><integer>0</integer>
            <key>iconSize</key><integer>80</integer>
          </dict>
        </dict>
        </plist>
        """
        let seeded = try #require(
            try PropertyListSerialization.propertyList(from: Data(plistXML.utf8), format: nil) as? [String: Any]
        )
        system.setDictionary(seeded, for: "DesktopViewSettings", in: finder)

        let requests: [(Tweak, TweakOption.ID)] = [
            (tweak("desktop.stacks"), "kind"),
            (tweak("desktop.arrange-by"), "grid"),
            (tweak("desktop.icon-size"), tweak("desktop.icon-size").optionID(for: .int(104))),
            (tweak("desktop.grid-spacing"), tweak("desktop.grid-spacing").optionID(for: .int(72))),
            (tweak("desktop.text-size"), tweak("desktop.text-size").optionID(for: .int(14))),
            (tweak("desktop.label-position"), "right"),
            (tweak("desktop.item-info"), "on"),
            (tweak("desktop.icon-preview"), "off"),
        ]
        #expect(requests.count == 8)

        let applied = await engine.apply(engine.plan(requests))
        #expect(applied.allSatisfy { $0.outcome.isApplied })

        // Every sibling key at both levels must remain intact after apply.
        let afterApply = try #require(system.dictionary(for: "DesktopViewSettings", in: finder))
        #expect((afterApply["WindowState"] as? [String: Bool]) == ["ShowSidebar": true])
        #expect(afterApply["GroupBy"] as? String == "Kind")
        let iconsAfterApply = try #require(afterApply["IconViewSettings"] as? [String: Any])
        #expect(iconsAfterApply["viewOptionsVersion"] as? Int == 1)
        #expect(iconsAfterApply["backgroundType"] as? Int == 0)
        #expect(iconsAfterApply["backgroundColorRed"] as? Double == 1.0)
        #expect(iconsAfterApply["gridOffsetX"] as? Int == 0)
        #expect(iconsAfterApply["iconSize"] as? Int == 104)
        #expect(iconsAfterApply["labelOnBottom"] as? Bool == false)

        // Undo all eight changes and prove the dictionary matches the exact original state.
        let revertRequests = try applied.map { ($0.change.tweak, try #require($0.snapshot)) }
        let reverted = await engine.apply(engine.revertPlan(revertRequests))
        #expect(reverted.allSatisfy { $0.outcome.isApplied })

        let afterUndo = try #require(system.dictionary(for: "DesktopViewSettings", in: finder))
        #expect((afterUndo as NSDictionary) == (seeded as NSDictionary))
        // Confirm `iconSize` came back as a typed integer (not a string or float).
        let restoredIconSize = try #require((afterUndo["IconViewSettings"] as? [String: Any])?["iconSize"]) as AnyObject
        #expect(CFGetTypeID(restoredIconSize) == CFNumberGetTypeID())
        let isFloat = CFNumberIsFloatType(unsafeDowncast(restoredIconSize, to: CFNumber.self))
        #expect(!isFloat)

        // Also prove that on a brand-new account where DesktopViewSettings is absent,
        // applying and undoing removes the empty wrapper dictionaries completely.
        let (freshEngine, freshSystem) = makeEngine()
        let freshApplied = await freshEngine.apply(freshEngine.plan(requests))
        #expect(freshSystem.dictionary(for: "DesktopViewSettings", in: finder) != nil)
        let freshReverts = try freshApplied.map { ($0.change.tweak, try #require($0.snapshot)) }
        _ = await freshEngine.apply(freshEngine.revertPlan(freshReverts))
        #expect(freshSystem.dictionary(for: "DesktopViewSettings", in: finder) == nil)
    }
}

@Suite struct PlanTests {
    @Test func `plans describe the equivalent commands`() {
        let (engine, _) = makeEngine()
        let plan = engine.plan([
            (tweak("finder.hidden-files"), "on"),
            (tweak("dock.reveal-speed"), "standard"),
            (tweak("finder.library"), "on"),
            (tweak("security.firewall"), "on"),
        ])
        #expect(plan.changes.flatMap(\.operations).map(\.commandText) == [
            "defaults write com.apple.finder AppleShowAllFiles -bool true",
            "defaults delete com.apple.dock autohide-delay",
            "defaults delete com.apple.dock autohide-time-modifier",
            "chflags nohidden ~/Library",
            "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on",
        ])
    }

    @Test func `planning has no side effects`() async {
        let (engine, system) = makeEngine()
        _ = engine.plan([(tweak("finder.hidden-files"), "on"), (tweak("security.firewall"), "on")])
        #expect(system.commandsRun.isEmpty)
        #expect(system.privilegedBatches.isEmpty)
        #expect(await engine.state(of: tweak("finder.hidden-files")) == .option("off"))
    }

    @Test func `restarts are deduplicated and ordered`() {
        let (engine, _) = makeEngine()
        let plan = engine.plan([
            (tweak("dock.autohide"), "on"),
            (tweak("finder.path-bar"), "on"),
            (tweak("finder.status-bar"), "on"),
            (tweak("text.autocorrect"), "off"),
        ])
        #expect(plan.restarts == [.finder, .dock])
        #expect(plan.needsAppRelaunch)
        #expect(!plan.needsLogout)
    }

    @Test func `values with spaces are quoted`() {
        let spaced = URL(filePath: "/Users/Sam Example")
        let location = Catalog.tweaks(home: spaced).first { $0.id == "screenshot.location" }!
        let (engine, _) = makeEngine()
        let text = engine.plan([(location, "pictures")]).changes[0].operations[0].commandText
        #expect(text == "defaults write com.apple.screencapture location -string '/Users/Sam Example/Pictures'")
    }
}

@Suite struct ApplyTests {
    @Test func `applied changes restart only what they need`() async {
        let (engine, system) = makeEngine()
        _ = await engine.apply(engine.plan([(tweak("dock.autohide"), "on"), (tweak("text.autocorrect"), "off")]))
        #expect(system.commandsRun == [Command("/usr/bin/killall", "Dock")])
    }

    @Test func `privileged changes share one authorization`() async {
        let (engine, system) = makeEngine()
        let results = await engine.apply(engine.plan([
            (tweak("security.firewall"), "on"),
            (tweak("finder.hidden-files"), "on"),
            (tweak("security.stealth"), "on"),
        ]))
        #expect(results.allSatisfy { $0.outcome.isApplied })
        #expect(system.privilegedBatches.count == 1)
        #expect(system.privilegedBatches.first?.count == 2)
    }

    @Test func `a cancelled authorization fails only the privileged changes`() async {
        let (engine, system) = makeEngine()
        system.failAuthorization(with: .authorizationCancelled)
        let results = await engine.apply(engine.plan([
            (tweak("finder.hidden-files"), "on"),
            (tweak("security.firewall"), "on"),
        ]))
        #expect(results.map(\.outcome) == [.applied, .failed(.authorizationCancelled)])
        #expect(await engine.state(of: tweak("security.firewall")) == .option("off"))
        #expect(results[1].snapshot == nil)
    }

    @Test func `a failing privileged command in a batch keeps snapshots for changes that succeeded and runs the rest`() async {
        let (engine, system) = makeEngine()
        system.failPrivilegedCommand(Command("/usr/bin/AssetCacheManagerUtil", "activate"))

        let results = await engine.apply(engine.plan([
            (tweak("security.firewall"), "on"),
            (tweak("sharing.content-caching"), "on"),
            (tweak("startup.chime"), "off"),
        ]))

        // Still one password prompt for the whole batch.
        #expect(system.privilegedBatches.count == 1)

        // Firewall and Startup chime succeeded and must keep their undo snapshots.
        #expect(results[0].outcome == .applied)
        #expect(results[0].snapshot == .privileged("off"))
        #expect(await engine.state(of: tweak("security.firewall")) == .option("on"))

        // Content caching failed and has no snapshot.
        #expect(!results[1].outcome.isApplied)
        #expect(results[1].snapshot == nil)
        #expect(await engine.state(of: tweak("sharing.content-caching")) == .option("off"))

        // Startup chime after the failed change still ran and can be undone.
        #expect(results[2].outcome == .applied)
        #expect(results[2].snapshot == .privileged("on"))
        #expect(await engine.state(of: tweak("startup.chime")) == .option("off"))
    }

    @Test func `a failed change does not stop the rest`() async {
        let (engine, system) = makeEngine()
        system.failWrites(to: "ShowPathbar")
        let results = await engine.apply(engine.plan([
            (tweak("finder.path-bar"), "on"),
            (tweak("finder.status-bar"), "on"),
        ]))
        #expect(!results[0].outcome.isApplied)
        #expect(results[1].outcome.isApplied)
    }

    @Test func `a half written tweak is rolled back`() async {
        let (engine, system) = makeEngine()
        system.failWrites(to: "autohide-time-modifier")
        let results = await engine.apply(engine.plan([(tweak("dock.reveal-speed"), "fast")]))
        #expect(!results[0].outcome.isApplied)
        #expect(system.value(for: "autohide-delay", in: .app("com.apple.dock")) == nil)
        #expect(system.commandsRun.isEmpty, "nothing was applied, so nothing should restart")
    }

    @Test func `progress is reported for every change`() async {
        let (engine, _) = makeEngine()
        var events: [String] = []
        _ = await engine.apply(engine.plan([(tweak("finder.path-bar"), "on")])) { id, progress in
            events.append("\(id):\(progress == .running ? "running" : "finished")")
        }
        #expect(events == ["finder.path-bar:running", "finder.path-bar:finished"])
    }
}

@Suite struct RevertTests {
    @Test func `reverting restores the exact prior value`() async throws {
        let (engine, system) = makeEngine()
        // A hand-set value MacKit doesn't offer as an option.
        try system.set(.double(0.2), for: "autohide-delay", in: .app("com.apple.dock"))
        let speed = tweak("dock.reveal-speed")

        let results = await engine.apply(engine.plan([(speed, "instant")]))
        let snapshot = try #require(results[0].snapshot)
        #expect(await engine.state(of: speed) == .option("instant"))

        _ = await engine.apply(engine.revertPlan([(speed, snapshot)]))
        #expect(system.value(for: "autohide-delay", in: .app("com.apple.dock")) == .double(0.2))
        #expect(system.value(for: "autohide-time-modifier", in: .app("com.apple.dock")) == nil)
    }

    @Test func `reverting a key that did not exist removes it`() async throws {
        let (engine, system) = makeEngine()
        let hidden = tweak("finder.hidden-files")
        let results = await engine.apply(engine.plan([(hidden, "on")]))
        _ = await engine.apply(engine.revertPlan([(hidden, try #require(results[0].snapshot))]))
        #expect(system.value(for: "AppleShowAllFiles", in: .app("com.apple.finder")) == nil)
    }

    @Test func `reverting a privileged change runs the prior option`() async throws {
        let (engine, system) = makeEngine()
        let firewall = tweak("security.firewall")
        let results = await engine.apply(engine.plan([(firewall, "on")]))
        _ = await engine.apply(engine.revertPlan([(firewall, try #require(results[0].snapshot))]))
        #expect(await engine.state(of: firewall) == .option("off"))
        #expect(system.privilegedBatches.count == 2)
    }

    @Test func `library visibility round trips`() async throws {
        let (engine, _) = makeEngine()
        let library = tweak("finder.library")
        let results = await engine.apply(engine.plan([(library, "on")]))
        #expect(await engine.state(of: library) == .option("on"))
        _ = await engine.apply(engine.revertPlan([(library, try #require(results[0].snapshot))]))
        #expect(await engine.state(of: library) == .option("off"))
    }
}

@Suite struct CommandTests {
    @Test(arguments: [
        (["a b"], "/bin/x 'a b'"),
        (["it's"], "/bin/x 'it'\\''s'"),
        ([""], "/bin/x ''"),
        (["$(rm -rf /)"], "/bin/x '$(rm -rf /)'"),
        (["StartupMute=%01"], "/bin/x StartupMute=%01"),
    ])
    func `shell text quotes unsafe words`(arguments: [String], expected: String) {
        #expect(Command(executable: "/bin/x", arguments: arguments).shellText == expected)
    }

    @Test func `the live runner refuses anything off the allowlist`() async {
        await #expect(throws: SystemError.commandNotAllowed("/bin/rm")) {
            try await AllowlistedCommandRunner().run(Command("/bin/rm", "-rf", "/tmp/nothing"))
        }
    }

    @Test func `touch id for sudo keeps pam syntax and read-only permissions intact`() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "mackit-pam-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer {
            chmod(dir.appending(path: "sudo_local").path(percentEncoded: false), 0o644)
            try? FileManager.default.removeItem(at: dir)
        }

        let targetPath = dir.appending(path: "sudo_local").path(percentEncoded: false)
        try Data("# sudo_local\n#auth       sufficient     pam_tid.so\n".utf8)
            .write(to: URL(filePath: targetPath + ".template"))

        let (engine, _) = makeEngine()
        let pamTweak = tweak("security.touch-id-sudo")

        func runCommands(for option: String) throws -> Int32 {
            let ops = engine.plan([(pamTweak, option)]).changes[0].operations
            for op in ops {
                let cmd = try #require(op.privilegedCommand)
                let p = Process()
                p.executableURL = URL(filePath: cmd.executable)
                p.arguments = cmd.arguments.map { $0.replacing("/etc/pam.d/sudo_local", with: targetPath) }
                try p.run()
                p.waitUntilExit()
                if p.terminationStatus != 0, !cmd.toleratesFailure { return p.terminationStatus }
            }
            return 0
        }

        // Turning off when /etc/pam.d/sudo_local does not exist yet must succeed cleanly.
        #expect(try runCommands(for: "off") == 0)

        // Existing file without a trailing newline must not concatenate onto the prior PAM rule.
        try Data("auth       optional       pam_reattach.so".utf8).write(to: URL(filePath: targetPath))
        chmod(targetPath, 0o666)
        #expect(try runCommands(for: "on") == 0)

        let text = try String(contentsOfFile: targetPath, encoding: .utf8)
        let lines = text.split(separator: "\n").map(String.init)
        #expect(lines == [
            "auth       optional       pam_reattach.so",
            "auth       sufficient     pam_tid.so",
        ])
        let mode = try FileManager.default.attributesOfItem(atPath: targetPath)[.posixPermissions] as? Int ?? 0
        #expect((mode & 0o022) == 0, "OpenPAM rejects group/world-writable PAM files (got \(String(mode, radix: 8)))")

        // Turning off comments out pam_tid.so while keeping pam_reattach.so untouched.
        #expect(try runCommands(for: "off") == 0)
        let disabled = try String(contentsOfFile: targetPath, encoding: .utf8)
        #expect(disabled.contains("auth       optional       pam_reattach.so\n#auth       sufficient     pam_tid.so"))
    }

    @Test func `file-backed system plists stay world-readable after root defaults write`() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "mackit-sysplist-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let fakeBase = dir.appending(path: "com.apple.captive.control").path(percentEncoded: false)
        let (engine, _) = makeEngine()
        let captive = tweak("network.captive-portal")
        let commands = engine.plan([(captive, "off")]).changes[0].operations.compactMap(\.privilegedCommand)

        for cmd in commands {
            let p = Process()
            p.executableURL = URL(filePath: cmd.executable)
            p.arguments = cmd.arguments.map {
                $0.replacing("/Library/Preferences/SystemConfiguration/com.apple.captive.control", with: fakeBase)
            }
            try p.run()
            p.waitUntilExit()
            if !cmd.toleratesFailure { #expect(p.terminationStatus == 0) }
        }

        let mode = try FileManager.default.attributesOfItem(atPath: fakeBase + ".plist")[.posixPermissions] as? Int ?? 0
        #expect((mode & 0o044) == 0o044, "expected 0644 so non-root readers can read the plist, got \(String(mode, radix: 8))")
    }

    @Test func `privileged batch script isolates per-change failures in sh`() throws {
        let groups = [
            PrivilegedGroup(id: "first", commands: [Command("/bin/echo", "noisy stdout")]),
            PrivilegedGroup(id: "second", commands: [Command("/bin/sh", "-c", "echo 'permission problem' >&2; exit 7")]),
            PrivilegedGroup(id: "third", commands: [
                Command(executable: "/usr/bin/false", arguments: [], toleratesFailure: true),
                Command("/usr/bin/true"),
            ]),
        ]
        let script = PrivilegedBatchScript.build(for: groups)
        let p = Process()
        p.executableURL = URL(filePath: "/bin/sh")
        p.arguments = ["-c", script]
        let out = Pipe()
        p.standardOutput = out
        try p.run()
        p.waitUntilExit()
        #expect(p.terminationStatus == 0)

        let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let parsed = PrivilegedBatchScript.parse(text, for: groups)
        try #require(parsed["first"]).get()
        try #require(parsed["third"]).get()
        if case .failure(.commandFailed(_, let code, let message))? = parsed["second"] {
            #expect(code == 7)
            #expect(message == "permission problem")
        } else {
            Issue.record("Expected second group to report exit code 7 and stderr")
        }
    }
}

@Suite struct HistoryTests {
    @Test func `history survives a save and load`() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "mackit-\(UUID().uuidString)/history.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = HistoryStore(fileURL: url)
        #expect(try store.load().isEmpty)

        let record = HistoryRecord(date: Date(timeIntervalSince1970: 1_800_000_000), entries: [
            HistoryEntry(
                tweakID: "finder.hidden-files", title: "Show hidden files", category: .finder,
                from: "Off", to: "On",
                snapshot: .preferences([PreferenceSnapshot(domain: .app("com.apple.finder"), key: "AppleShowAllFiles", value: nil)])
            ),
            HistoryEntry(
                tweakID: "security.firewall", title: "Firewall", category: .security,
                from: "Off", to: "On", snapshot: .privileged(nil)
            ),
        ])
        try store.save([record])
        let loaded = try store.load()
        #expect(loaded == [record])
        #expect(loaded[0].entries[0].canRevert)
        #expect(!loaded[0].entries[1].canRevert, "an unreadable prior state can't be restored")

        // Older history files without `section` or `path` still decode cleanly.
        let legacyJSON = Data(#"""
        [{"date":"2026-11-16T12:00:00Z","entries":[{"category":"finder","from":"Off","id":"00000000-0000-0000-0000-000000000002","snapshot":{"preferences":{"_0":[{"domain":{"app":{"_0":"com.apple.finder"}},"key":"AppleShowAllFiles"}]}},"title":"Show hidden files","to":"On","tweakID":"finder.hidden-files"}],"id":"00000000-0000-0000-0000-000000000001"}]
        """#.utf8)
        try legacyJSON.write(to: url)
        let legacy = try store.load()
        #expect(legacy.count == 1)
        #expect(legacy[0].entries[0].section == nil)
        #expect(legacy[0].entries[0].canRevert)

        // An entry written by a newer version with an unknown category must not break the rest of the file.
        let newerJSON = Data(#"""
        [{"date":"2026-11-16T12:00:00Z","entries":[
          {"category":"finder","from":"Off","id":"00000000-0000-0000-0000-000000000003","snapshot":{"preferences":{"_0":[{"domain":{"app":{"_0":"com.apple.finder"}},"key":"AppleShowAllFiles"}]}},"title":"Show hidden files","to":"On","tweakID":"finder.hidden-files"},
          {"category":"futureCategory","from":"Off","id":"00000000-0000-0000-0000-000000000004","snapshot":{"libraryHidden":{"_0":true}},"title":"Future tweak","to":"On","tweakID":"future.tweak"}
        ],"id":"00000000-0000-0000-0000-000000000005"}]
        """#.utf8)
        try newerJSON.write(to: url)
        let partiallyLoaded = try store.load()
        #expect(partiallyLoaded.first?.entries.map(\.tweakID) == ["finder.hidden-files"])

        // Saving after a corrupt history file backs up the unreadable bytes rather than destroying them.
        try Data("corrupt{{{".utf8).write(to: url)
        #expect(throws: (any Error).self) { try store.load() }
        try store.save([record])
        let siblings = try FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
        let backup = try #require(siblings.first { $0.lastPathComponent != "history.json" })
        #expect(try String(contentsOf: backup, encoding: .utf8) == "corrupt{{{")
    }
}

@Suite struct HardwareAndPowerTests {
    private struct DesktopRunner: CommandRunning {
        func run(_ command: Command) async throws(SystemError) -> CommandOutput {
            switch (command.executable, command.arguments) {
            case ("/usr/sbin/ioreg", ["-rd1", "-c", "AppleSmartBattery"]):
                // Desktop Macs (Mac mini, Mac Studio, iMac, Mac Pro) have no battery node.
                return CommandOutput(exitCode: 0, standardOutput: "", standardError: "")
            case ("/usr/sbin/ioreg", ["-rd1", "-c", "IOPMrootDomain"]):
                return CommandOutput(exitCode: 0, standardOutput: #""SleepDisabled" = No"#, standardError: "")
            case ("/usr/sbin/nvram", ["BootPreference"]):
                return CommandOutput(exitCode: 1, standardOutput: "", standardError: "nvram: Error getting variable")
            case ("/usr/bin/pmset", ["-g", "custom"]):
                return CommandOutput(exitCode: 0, standardOutput: """
                AC Power:
                 displaysleep         45
                 sleep                120
                 disksleep            1
                """, standardError: "")
            default:
                return CommandOutput(exitCode: 0, standardOutput: "", standardError: "")
            }
        }
    }

    @Test func `system settings sleep durations read cleanly and laptop-only settings hide on desktop Macs`() async {
        let tweaks = Catalog.tweaks(home: home)
        let fake = InMemorySystem(tweaks: tweaks)
        var access = fake.access(home: home)
        access.commands = DesktopRunner()
        let engine = TweakEngine(system: access)
        let states = await engine.states(of: tweaks)

        // 45 minutes, 2 hours (120), and disksleep 1 from System Settings must be recognized, not unknown.
        #expect(states["power.adapter.display"] == .option("45"))
        #expect(states["power.adapter.sleep"] == .option("120"))
        #expect(states["power.disk-sleep"] != .unknown)

        // Laptop-only battery and lid settings must report unknown + hardware-dependent on a desktop Mac.
        for id in ["power.lid-closed", "startup.auto-boot", "menubar.battery-percentage", "sound.charging-chime"] {
            let item = tweaks.first { $0.id == id }!
            #expect(item.isHardwareDependent, "\(id) must be marked hardware-dependent")
            #expect(states[id] == .unknown, "\(id) must be hidden on a desktop Mac without a battery")
        }
    }
}

@Suite struct SearchTests {
    @Test(arguments: [
        ("dock size", "dock.size"),
        ("mouse speed", "mouse.speed"),
        ("finder hidden", "finder.hidden-files"),
        ("safari url", "safari.full-url"),
        ("menubar seconds", "clock.seconds"),
        ("dark mode", "appearance.mode"),
        ("celsius", "region.temperature"),
        ("cpu", "activity.dock-icon"),
        ("AppleShowAllFiles", "finder.hidden-files"),
        ("clamshell", "power.lid-closed"),
    ])
    func `everyday multi-word, option, key, and synonym queries find the right setting`(query: String, expectedID: Tweak.ID) {
        let results = Catalog.search(query, in: Catalog.tweaks(home: home))
        #expect(results.contains { $0.id == expectedID }, "\(query) should find \(expectedID)")
        #expect(results.prefix(3).contains { $0.id == expectedID }, "\(expectedID) should rank near the top for \(query)")
    }

    @Test func `title and category matches rank ahead of incidental section matches`() {
        let results = Catalog.search("sound", in: Catalog.tweaks(home: home))
        let firstSoundIndex = results.firstIndex { $0.category == .sound || $0.id == "startup.chime" } ?? .max
        let firstFinderAnimIndex = results.firstIndex { $0.id == "finder.info-animation" } ?? .max
        #expect(firstSoundIndex < firstFinderAnimIndex)
    }

    @Test func `search matches capitalized I titles in Turkish and Azerbaijani locales`() {
        let all = Catalog.tweaks(home: home)
        let turkish = Locale(identifier: "tr_TR")
        #expect(Catalog.search("ICON", in: all, locale: turkish).contains { $0.id == "finder.sidebar-size" })
        #expect(Catalog.search("İcon", in: all, locale: turkish).first?.id == "dock.size"
            || Catalog.search("İcon", in: all, locale: turkish).prefix(3).contains { $0.id == "desktop.icon-size" })
        #expect(Catalog.search("icon", in: all, locale: turkish).prefix(3).contains { $0.id == "dock.size" || $0.id == "desktop.icon-size" })
        #expect(Catalog.search("input", in: all, locale: turkish).prefix(3).contains { $0.id == "menubar.input-menu" })
        #expect(Catalog.search("invisible", in: all, locale: turkish).prefix(3).contains { $0.id == "xcode.invisibles" })
    }
}
