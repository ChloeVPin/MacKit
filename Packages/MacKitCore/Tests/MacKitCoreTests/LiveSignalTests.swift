import Foundation
import Synchronization
import Testing
@testable import MacKitCore

struct LiveSignalTests {
    @Test func savingASettingTellsMacOSOnce() async throws {
        let home = URL(filePath: "/Users/sample")
        let tweaks = Catalog.tweaks(home: home)
        let sent = Mutex<[LiveSignal]>([])
        var access = InMemorySystem(tweaks: tweaks).access(home: home)
        access.announce = { signal in sent.withLock { $0.append(signal) } }
        let engine = TweakEngine(system: access)

        let mode = try #require(tweaks.first { $0.id == "appearance.mode" })
        let glass = try #require(tweaks.first { $0.id == "appearance.glass-tint" })
        _ = await engine.apply(engine.plan([(mode, "dark"), (glass, glass.options.last!.id)]))
        #expect(sent.withLock { $0 } == [.appearance, .glass])

        // A setting macOS has no signal for sends nothing.
        let hidden = try #require(tweaks.first { $0.id == "finder.hidden-files" })
        _ = await engine.apply(engine.plan([(hidden, "on")]))
        #expect(sent.withLock { $0 }.count == 2)
    }

    @Test func settingsThatApplyLiveHaveASignal() throws {
        let tweaks = Catalog.tweaks(home: URL(filePath: "/Users/sample"))
        let expected: [String: LiveSignal] = [
            "appearance.mode": .appearance, "appearance.accent": .appearance, "appearance.glass-tint": .glass,
            "appearance.wallpaper-tint": .wallpaperTint, "windows.scroll-bars": .scrollBars, "finder.sidebar-size": .sidebarSize,
            "menubar.autohide": .menuBar, "menubar.fullscreen": .menuBar, "access.pointer-size": .pointerSize,
            "keyboard.navigation": .keyboardNavigation, "trackpad.tap-to-click": .inputDevices, "mouse.speed": .inputDevices,
            "keyboard.function-keys": .inputDevices, "access.reduce-motion": .reduceMotion,
            "access.reduce-transparency": .reduceTransparency, "access.increase-contrast": .increaseContrast,
        ]
        for (id, signal) in expected {
            let tweak = try #require(tweaks.first { $0.id == id }, "\(id) is in the catalog")
            #expect(tweak.liveSignal == signal, "\(id)")
        }
    }

    @Test func glassLegibilityMetadataMatchesExpectedLayoutAndGuardsChanges() throws {
        let handle = try #require(dlopen("/System/Library/Frameworks/AppKit.framework/AppKit", RTLD_LAZY))
        let layout = try #require(glassLegibilityLayout(in: handle))
        #expect(layout == GlassLegibilityLayout(size: 5, stride: 8, tintAmountTag: 0))

        let valid = try #require(glassLegibilityBuffer(amount: 0.5, layout: layout))
        #expect(valid.count == 8)
        #expect(valid[4] == 0 && valid[5] == 0)

        // Any change to Legibility's size, stride, or case tag refuses to build the raw buffer.
        #expect(glassLegibilityBuffer(amount: 0.5, layout: .init(size: 9, stride: 16, tintAmountTag: 0)) == nil)
        #expect(glassLegibilityBuffer(amount: 0.5, layout: .init(size: 5, stride: 8, tintAmountTag: 1)) == nil)
    }
}
