import Foundation

private let clock = PreferenceDomain.app("com.apple.menuextra.clock")
private let access = PreferenceDomain.app("com.apple.universalaccess")

extension Catalog {
    static let appearanceMore: [Tweak] = [
        Tweak(
            id: "appearance.mode", title: "Appearance",
            summary: "Light, dark, or changing with the time of day.",
            category: .appearance, section: "Colors",
            options: [TweakOption("light", "Light"), TweakOption("dark", "Dark"), TweakOption("auto", "Auto")],
            stock: "light",
            // In Auto, macOS sets `AppleInterfaceStyle` to Dark at night and
            // removes it by day, so either value still means Auto.
            mechanism: .preferences([
                PreferenceBinding(.global, "AppleInterfaceStyle", ["dark": .string("Dark")], ignoredWhenReading: ["auto"]),
                PreferenceBinding(
                    .global, "AppleInterfaceStyleSwitchesAutomatically",
                    ["light": .bool(false), "dark": .bool(false), "auto": .bool(true)],
                    isOptionalOnRead: true
                ),
            ]),
            effect: .immediate
        ),
        Tweak(
            id: "appearance.accent", title: "Accent color",
            summary: "The color of buttons, switches, and selections.",
            category: .appearance, section: "Colors",
            options: [
                TweakOption("multicolor", "Multicolor"), TweakOption("blue", "Blue"), TweakOption("purple", "Purple"),
                TweakOption("pink", "Pink"), TweakOption("red", "Red"), TweakOption("orange", "Orange"),
                TweakOption("yellow", "Yellow"), TweakOption("green", "Green"), TweakOption("graphite", "Graphite"),
            ],
            stock: "multicolor",
            // Multicolor is the absence of the key.
            mechanism: .preferences([
                PreferenceBinding(.global, "AppleAccentColor", [
                    "graphite": .int(-1), "red": .int(0), "orange": .int(1), "yellow": .int(2), "green": .int(3),
                    "blue": .int(4), "purple": .int(5), "pink": .int(6),
                ])
            ]),
            effect: .immediate
        ),
        Tweak(
            id: "appearance.font-smoothing", title: "Font smoothing",
            summary: "How heavy text looks on screens that aren't Retina.",
            category: .appearance, section: "Details",
            options: [
                TweakOption("standard", "Standard"), TweakOption("off", "Off"), TweakOption("light", "Light"),
                TweakOption("medium", "Medium"), TweakOption("strong", "Strong"),
            ],
            stock: "standard",
            mechanism: .preferences([
                PreferenceBinding(.currentHostGlobal, "AppleFontSmoothing", [
                    "off": .int(0), "light": .int(1), "medium": .int(2), "strong": .int(3),
                ])
            ]),
            effect: .appRelaunch
        ),
        .choice("appearance.scroll-bar-click", "Click in the scroll bar to", "What a click in the empty part of a scroll bar does.",
                in: .appearance, "Details", .global, "AppleScrollerPagingBehavior",
                [("page", "Jump to the Next Page", .bool(false)), ("spot", "Jump to the Spot Clicked", .bool(true))],
                stock: "page", effect: .appRelaunch),
        .toggle("appearance.rubber-band", "Bounce at the end of a scroll", "Stretch past the edge and spring back.",
                in: .appearance, "Details", .global, "NSScrollViewRubberbanding", stock: true, effect: .appRelaunch),
    ]

    static let menuBarClock: [Tweak] = [
        .choice("clock.style", "Clock style", "Numbers or a small clock face.",
                in: .menuBar, "Clock", clock, "IsAnalog", [("digital", "Digital", .bool(false)), ("analog", "Analog", .bool(true))],
                stock: "digital", effect: .restarts(.controlCenter)),
        .toggle("clock.seconds", "Show seconds", "Count the seconds in the menu bar clock.",
                in: .menuBar, "Clock", clock, "ShowSeconds", stock: false, effect: .restarts(.controlCenter)),
        .choice("clock.date", "Show the date", "Whether the date sits beside the time.",
                in: .menuBar, "Clock", clock, "ShowDate",
                [("auto", "When Space Allows", .int(0)), ("always", "Always", .int(1)), ("never", "Never", .int(2))],
                stock: "auto", effect: .restarts(.controlCenter)),
        .toggle("clock.weekday", "Show the day of the week", "Put the day before the date and time.",
                in: .menuBar, "Clock", clock, "ShowDayOfWeek", stock: true, effect: .restarts(.controlCenter)),
        .toggle("clock.am-pm", "Show AM and PM", "Only matters with a 12-hour clock.",
                in: .menuBar, "Clock", clock, "ShowAMPM", stock: true, effect: .restarts(.controlCenter)),
        .toggle("clock.flash", "Flash the time separators", "Blink the colon once a second.",
                in: .menuBar, "Clock", clock, "FlashDateSeparators", stock: false, effect: .restarts(.controlCenter)),
        .toggle("menubar.battery-percentage", "Battery percentage", "Show the charge as a number beside the battery icon.",
                in: .menuBar, "Items", .currentHost("com.apple.controlcenter"), "BatteryShowPercentage", stock: false,
                effect: .restarts(.controlCenter), requiresBattery: true),
        .toggle("menubar.siri", "Siri", "The Siri icon in the menu bar.",
                in: .menuBar, "Items", .app("com.apple.Siri"), "StatusMenuVisible", stock: true, effect: .restarts(.systemUIServer)),
    ]

    static let sound: [Tweak] = [
        .choice("sound.alert-volume", "Alert volume", "How loud alert sounds are, compared with everything else.",
                in: .sound, "Sound Effects", .global, "com.apple.sound.beep.volume",
                [("off", "Silent", .double(0)), ("25", "25%", .double(0.4723665)), ("50", "50%", .double(0.6065307)),
                 ("75", "75%", .double(0.7788008)), ("100", "100%", .double(1))],
                stock: "100", effect: .logout),
        .choice("sound.interface", "Interface sound effects", "Sounds for things like dragging to the Trash.",
                in: .sound, "Sound Effects", .global, "com.apple.sound.uiaudio.enabled", [("off", "Off", .int(0)), ("on", "On", .int(1))],
                stock: "on", effect: .logout),
        .choice("sound.volume-feedback", "Feedback when volume changes", "Play a pop when you press the volume keys.",
                in: .sound, "Sound Effects", .global, "com.apple.sound.beep.feedback", [("off", "Off", .int(0)), ("on", "On", .int(1))],
                stock: "off", effect: .logout),
        .choice("sound.flash", "Flash the screen for alerts", "Flash the display whenever an alert sounds.",
                in: .sound, "Sound Effects", .global, "com.apple.sound.beep.flash", [("off", "Off", .int(0)), ("on", "On", .int(1))],
                stock: "off", effect: .logout),
        .toggle("sound.charging-chime", "Charging chime", "Play a sound when you plug in the power adapter.",
                in: .sound, "Sound Effects", .app("com.apple.PowerChime"), "ChimeOnNoHardware", stock: true,
                on: .bool(false), off: .bool(true), effect: .logout, requiresBattery: true),
    ]

    static let region: [Tweak] = [
        Tweak(
            id: "region.clock", title: "Time format",
            summary: "A 12-hour or 24-hour clock everywhere.",
            category: .system, section: "Language and Region",
            options: [TweakOption("region", "Follow Region"), TweakOption("24", "24-Hour"), TweakOption("12", "12-Hour")],
            stock: "region",
            mechanism: .preferences([
                PreferenceBinding(.global, "AppleICUForce24HourTime", ["24": .bool(true)]),
                PreferenceBinding(.global, "AppleICUForce12HourTime", ["12": .bool(true)]),
            ]),
            effect: .logout
        ),
        Tweak(
            id: "region.temperature", title: "Temperature",
            summary: "The unit used in Weather and elsewhere.",
            category: .system, section: "Language and Region",
            options: [TweakOption("region", "Follow Region"), TweakOption("celsius", "Celsius"), TweakOption("fahrenheit", "Fahrenheit")],
            stock: "region",
            mechanism: .preferences([
                PreferenceBinding(.global, "AppleTemperatureUnit", ["celsius": .string("Celsius"), "fahrenheit": .string("Fahrenheit")])
            ]),
            effect: .appRelaunch
        ),
        Tweak(
            id: "region.measurement", title: "Measurement system",
            summary: "Centimeters or inches in rulers and page sizes.",
            category: .system, section: "Language and Region",
            options: [TweakOption("region", "Follow Region"), TweakOption("metric", "Metric"), TweakOption("us", "US")],
            stock: "region",
            mechanism: .preferences([
                PreferenceBinding(.global, "AppleMeasurementUnits", ["metric": .string("Centimeters"), "us": .string("Inches")], isOptionalOnRead: true),
                PreferenceBinding(.global, "AppleMetricUnits", ["metric": .bool(true), "us": .bool(false)], isOptionalOnRead: true),
            ]),
            effect: .appRelaunch
        ),
    ]

    static let accessibility: [Tweak] = [
        .toggle("access.reduce-motion", "Reduce motion", "Replace sliding and zooming animations with gentle fades.",
                in: .accessibility, "Display", access, "reduceMotion", stock: false, effect: .logout),
        .toggle("access.reduce-transparency", "Reduce transparency", "Make glass and see-through surfaces solid.",
                in: .accessibility, "Display", access, "reduceTransparency", stock: false, effect: .logout),
        .toggle("access.increase-contrast", "Increase contrast", "Add stronger borders and darker text.",
                in: .accessibility, "Display", access, "increaseContrast", stock: false, effect: .logout),
        .toggle("access.without-color", "Differentiate without color", "Use shapes as well as color to show status.",
                in: .accessibility, "Display", access, "differentiateWithoutColor", stock: false, effect: .logout),
        .toggle("access.title-icons", "Show window title icons", "Always show the folder or document icon in window titles.",
                in: .accessibility, "Display", access, "showWindowTitlebarIcons", stock: false, effect: .restarts(.finder)),
        .toggle("access.button-shapes", "Show toolbar button shapes", "Draw an outline around toolbar buttons.",
                in: .accessibility, "Display", access, "showToolbarButtonShapes", stock: false, effect: .appRelaunch),

        .slider("access.pointer-size", "Pointer size", "How large the mouse pointer is.",
                in: .accessibility, "Pointer", access, "mouseDriverCursorSize",
                NumberInput(1...4, step: 0.25, unit: "×"), stock: 1),
        .toggle("access.shake-to-locate", "Shake the pointer to locate it", "Wiggle the mouse to make the pointer grow for a moment.",
                in: .accessibility, "Pointer", .global, "CGDisableCursorLocationMagnification", stock: true,
                on: .bool(false), off: .bool(true), effect: .logout),

        Tweak(
            id: "access.scroll-zoom", title: "Zoom by scrolling with a key held",
            summary: "Hold a key and scroll to magnify the whole screen.",
            category: .accessibility, section: "Zoom",
            options: [TweakOption("off", "Off"), TweakOption("control", "Control"), TweakOption("option", "Option"), TweakOption("command", "Command")],
            stock: "off",
            mechanism: .preferences([
                PreferenceBinding(access, "closeViewScrollWheelToggle", [
                    "off": .bool(false), "control": .bool(true), "option": .bool(true), "command": .bool(true),
                ]),
                PreferenceBinding(access, "HIDScrollZoomModifierMask", [
                    "off": .int(262_144), "control": .int(262_144), "option": .int(524_288), "command": .int(1_048_576),
                ], ignoredWhenReading: ["off"], isOptionalOnRead: true),
            ]),
            effect: .logout
        ),
        .toggle("access.zoom-shortcuts", "Zoom keyboard shortcuts", "Option-Command-8 and friends zoom the screen.",
                in: .accessibility, "Zoom", access, "closeViewHotkeysEnabled", stock: false, effect: .logout),
        .toggle("access.zoom-follows-focus", "Zoom follows keyboard focus", "Keep what you're typing in view while zoomed.",
                in: .accessibility, "Zoom", access, "closeViewZoomFollowsFocus", stock: false, effect: .logout),
        .toggle("access.zoom-smoothing", "Smooth zoomed images", "Soften pixels when the screen is magnified.",
                in: .accessibility, "Zoom", access, "closeViewSmoothImages", stock: true, effect: .logout),

        .toggle("access.sticky-keys", "Sticky Keys", "Press modifier keys one at a time instead of holding them.",
                in: .accessibility, "Keyboard", access, "stickyKey", stock: false, effect: .logout),
        .toggle("access.slow-keys", "Slow Keys", "Wait a moment before accepting each key press.",
                in: .accessibility, "Keyboard", access, "slowKey", stock: false, effect: .logout),
    ]
}
