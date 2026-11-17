import Foundation

extension Catalog {
    static let appearanceFromSystem: [Tweak] = [
        // Liquid Glass
        .slider(
            "appearance.glass-tint", "Liquid Glass tint",
            "How clear or frosted glass surfaces look. Lower shows more of what's behind.",
            in: .appearance, "Liquid Glass", .global, "NSGlassTintAmount",
            NumberInput(0...1, step: 0.01, unit: "%", displayScale: 100), stock: 0.5
        ),
        .toggle(
            "appearance.wallpaper-tint", "Tint windows with the wallpaper",
            "Let window backgrounds pick up a little color from the desktop picture.",
            in: .appearance, "Liquid Glass", .global, "AppleReduceDesktopTinting", stock: true,
            on: .bool(false), off: .bool(true)
        ),
        .choice(
            "appearance.corners", "Window corners",
            "How rounded window corners are. There's no switch for this in System Settings.",
            in: .appearance, "Liquid Glass", .global, "NSConvolutionOverride1",
            [
                ("square", "Slightly Rounded", .int(10)), ("medium", "Rounded", .int(15)),
                ("standard", "Standard", .int(20)), ("round", "Extra Rounded", .int(26)),
            ],
            stock: "standard", effect: .appRelaunch
        ),

        // Icons and widgets
        .choice(
            "appearance.icon-style", "Icon and widget style",
            "The look of app icons, folders, and widgets.",
            in: .appearance, "Icons and Widgets", .global, "AppleIconAppearanceTheme",
            [
                ("default", "Default", .string("RegularAutomatic")), ("default-light", "Default, Light", .string("RegularLight")),
                ("dark", "Dark", .string("RegularDark")), ("clear", "Clear", .string("ClearAutomatic")),
                ("clear-light", "Clear, Light", .string("ClearLight")), ("clear-dark", "Clear, Dark", .string("ClearDark")),
                ("tinted", "Tinted", .string("TintedAutomatic")), ("tinted-light", "Tinted, Light", .string("TintedLight")),
                ("tinted-dark", "Tinted, Dark", .string("TintedDark")),
            ],
            stock: "default", effect: .logout
        ),
        .choice(
            "appearance.icon-tint", "Icon tint color",
            "The color used when the icon style is Tinted.",
            in: .appearance, "Icons and Widgets", .global, "AppleIconAppearanceTintColor",
            [
                ("hardware", "Match This Mac", .string("Hardware")), ("red", "Red", .string("Red")), ("orange", "Orange", .string("Orange")),
                ("yellow", "Yellow", .string("Yellow")), ("green", "Green", .string("Green")), ("blue", "Blue", .string("Blue")),
                ("purple", "Purple", .string("Purple")), ("pink", "Pink", .string("Pink")), ("graphite", "Graphite", .string("Graphite")),
            ],
            stock: "hardware", effect: .logout
        ),

        // Interface details
        .toggle(
            "appearance.focus-ring", "Animate the focus ring",
            "The ring around a selected field shrinks into place.",
            in: .appearance, "Details", .global, "NSUseAnimatedFocusRing", stock: true, effect: .appRelaunch
        ),
        .slider(
            "appearance.tooltip-delay", "Tooltip delay",
            "How long to hover before a tooltip appears.",
            in: .appearance, "Details", .global, "NSInitialToolTipDelay",
            NumberInput(0...2000, step: 50, unit: " ms", isInteger: true), stock: 1000, effect: .appRelaunch
        ),
        .toggle(
            "appearance.smooth-scrolling", "Smooth scrolling",
            "Glide when you page with the keyboard or scroll bar.",
            in: .appearance, "Details", .global, "NSScrollAnimationEnabled", stock: true, effect: .appRelaunch
        ),
        .toggle(
            "appearance.control-characters", "Show control characters",
            "Display hidden characters in text as symbols.",
            in: .keyboard, "Typing", .global, "NSTextShowsControlCharacters", stock: false, effect: .appRelaunch
        ),
        .slider(
            "appearance.recent-documents", "Recent documents",
            "How many files each app lists under Open Recent.",
            in: .windows, "Documents", .global, "NSRecentDocumentsLimit",
            NumberInput(0...50, step: 1, isInteger: true), stock: 10, effect: .appRelaunch
        ),
        .toggle(
            "appearance.auto-quit", "Let idle apps quit themselves",
            "macOS closes apps with no windows to free memory. Turn off to keep them running.",
            in: .windows, "Behavior", .global, "NSDisableAutomaticTermination", stock: true,
            on: .bool(false), off: .bool(true), effect: .appRelaunch
        ),
        .toggle(
            "appearance.versions-debug", "Versions debug menu",
            "Add a Debug menu to the version browser in document apps.",
            in: .windows, "Documents", .global, "NSDocumentRevisionsDebugMode", stock: false, effect: .appRelaunch
        ),
    ]

    static let menuBarFromSystem: [Tweak] = [
        .toggle(
            "menubar.background", "Menu bar background",
            "Give the menu bar a solid backing instead of showing the wallpaper through it.",
            in: .menuBar, "Appearance", .global, "SLSMenuBarUseBlurredAppearance", stock: false, effect: .logout
        ),
        .toggle(
            "menubar.autohide", "Hide the menu bar automatically",
            "Keep the menu bar off screen until you move to the top.",
            in: .menuBar, "Appearance", .global, "_HIHideMenuBar", stock: false
        ),
        .toggle(
            "menubar.fullscreen", "Keep the menu bar in full screen",
            "Show the menu bar above full-screen apps.",
            in: .menuBar, "Appearance", .global, "AppleMenuBarVisibleInFullscreen", stock: false, effect: .logout
        ),
        .choice(
            "menubar.text-size", "Menu bar text size",
            "Larger menu titles and status text.",
            in: .menuBar, "Appearance", .global, "AppleMenuBarFontSize",
            [("default", "Default", .string("default")), ("large", "Large", .string("large"))],
            stock: "default", effect: .logout
        ),
        Tweak(
            id: "menubar.spacing", title: "Icon spacing",
            summary: "Pack menu bar icons closer together so more of them fit.",
            category: .menuBar, section: "Appearance",
            options: [TweakOption("standard", "Standard"), TweakOption("compact", "Compact"), TweakOption("tight", "Tight")],
            stock: "standard",
            // Standard removes both keys, which is how macOS ships.
            mechanism: .preferences([
                PreferenceBinding(.currentHostGlobal, "NSStatusItemSpacing", ["compact": .int(10), "tight": .int(6)]),
                PreferenceBinding(.currentHostGlobal, "NSStatusItemSelectionPadding", ["compact": .int(8), "tight": .int(4)]),
            ]),
            effect: .logout
        ),
        .toggle(
            "menubar.spotlight", "Spotlight",
            "The magnifying glass in the menu bar.",
            in: .menuBar, "Items", .currentHost("com.apple.Spotlight"), "MenuItemHidden", stock: true,
            on: .bool(false), off: .bool(true), effect: .logout
        ),
        .toggle(
            "menubar.input-menu", "Input menu",
            "Switch keyboard layouts and open the emoji picker from the menu bar.",
            in: .menuBar, "Items", .app("com.apple.TextInputMenu"), "visible", stock: false, effect: .logout
        ),
        .toggle(
            "menubar.live-activities", "Live Activities from iPhone",
            "Show timers, scores, and deliveries from your iPhone in the menu bar.",
            in: .menuBar, "Items", .app("com.apple.controlcenter"), "RemoteLiveActivitiesEnabled", stock: true,
            effect: .restarts(.controlCenter)
        ),
        .toggle(
            "spotlight.clipboard", "Clipboard history in Spotlight",
            "Keep the things you copy so you can paste them again later.",
            in: .menuBar, "Spotlight", .app("com.apple.Spotlight"), "PasteboardHistoryEnabled", stock: false,
            effect: .logout,
            caution: "On some macOS versions this turns itself back on after a restart."
        ),
        .choice(
            "spotlight.clipboard-keep", "Keep clipboard history for",
            "How long copied items stay available.",
            in: .menuBar, "Spotlight", .app("com.apple.Spotlight"), "PasteboardHistoryTimeout",
            [("30m", "30 Minutes", .int(1800)), ("8h", "8 Hours", .int(28_800)), ("7d", "7 Days", .int(604_800))],
            stock: "8h", effect: .logout
        ),
    ]
}
