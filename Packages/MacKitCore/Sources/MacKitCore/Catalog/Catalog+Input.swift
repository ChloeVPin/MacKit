import Foundation

private let builtIn = PreferenceDomain.app("com.apple.AppleMultitouchTrackpad")
private let bluetooth = PreferenceDomain.app("com.apple.driver.AppleBluetoothMultitouch.trackpad")

extension Catalog {
    /// A trackpad setting. The built-in trackpad and a Magic Trackpad keep
    /// separate copies of every key, so both are written together.
    private static func trackpad(
        _ id: String, _ title: String, _ summary: String, _ section: String, _ key: String,
        _ choices: [(id: TweakOption.ID, label: String, value: PreferenceValue)],
        stock: TweakOption.ID,
        also extra: [PreferenceBinding] = []
    ) -> Tweak {
        let values = Dictionary(uniqueKeysWithValues: choices.map { ($0.id, $0.value) })
        return Tweak(
            id: "trackpad.\(id)", title: title, summary: summary, category: .trackpad, section: section,
            options: choices.map { TweakOption($0.id, $0.label) },
            stock: stock,
            mechanism: .preferences([
                PreferenceBinding(builtIn, key, values, isOptionalOnRead: true),
                PreferenceBinding(bluetooth, key, values, isOptionalOnRead: true),
            ] + extra),
            effect: .logout
        )
    }

    private static let offOn: [(id: TweakOption.ID, label: String, value: PreferenceValue)] = [("off", "Off", .bool(false)), ("on", "On", .bool(true))]

    private static func offOn(_ on: Int) -> [(id: TweakOption.ID, label: String, value: PreferenceValue)] {
        [("off", "Off", .int(0)), ("on", "On", .int(on))]
    }

    static let trackpadAndMouse: [Tweak] = [
        // Point and click
        trackpad("tap-to-click", "Tap to click", "Tap with one finger instead of pressing down.", "Point and Click", "Clicking",
                 offOn, stock: "off",
                 also: [PreferenceBinding(.currentHostGlobal, "com.apple.mouse.tapBehavior", ["on": .int(1)], isOptionalOnRead: true)]),
        Tweak(
            id: "trackpad.secondary-click", title: "Secondary click",
            summary: "How to right-click on a trackpad.",
            category: .trackpad, section: "Point and Click",
            options: [
                TweakOption("two-fingers", "Click with Two Fingers"), TweakOption("bottom-right", "Click in Bottom-Right Corner"),
                TweakOption("bottom-left", "Click in Bottom-Left Corner"), TweakOption("off", "Off"),
            ],
            stock: "two-fingers",
            mechanism: .preferences([
                PreferenceBinding(builtIn, "TrackpadRightClick", [
                    "two-fingers": .bool(true), "bottom-right": .bool(false), "bottom-left": .bool(false), "off": .bool(false),
                ]),
                PreferenceBinding(builtIn, "TrackpadCornerSecondaryClick", [
                    "two-fingers": .int(0), "bottom-right": .int(2), "bottom-left": .int(1), "off": .int(0),
                ], valueWhenUnset: .int(0)),
                PreferenceBinding(bluetooth, "TrackpadRightClick", [
                    "two-fingers": .bool(true), "bottom-right": .bool(false), "bottom-left": .bool(false), "off": .bool(false),
                ], isOptionalOnRead: true),
                PreferenceBinding(bluetooth, "TrackpadCornerSecondaryClick", [
                    "two-fingers": .int(0), "bottom-right": .int(2), "bottom-left": .int(1), "off": .int(0),
                ], isOptionalOnRead: true),
            ]),
            effect: .logout
        ),
        .slider("trackpad.speed", "Tracking speed", "How far the pointer moves when you move your finger.",
                in: .trackpad, "Point and Click", .global, "com.apple.trackpad.scaling",
                NumberInput(0...3, step: 0.125, unit: "×"), stock: 1, effect: .logout),
        Tweak(
            id: "trackpad.click-pressure", title: "Click pressure",
            summary: "How hard you have to press for a click.",
            category: .trackpad, section: "Point and Click",
            options: [TweakOption("light", "Light"), TweakOption("medium", "Medium"), TweakOption("firm", "Firm")],
            stock: "medium",
            mechanism: .preferences([
                PreferenceBinding(builtIn, "FirstClickThreshold", ["light": .int(0), "medium": .int(1), "firm": .int(2)], isOptionalOnRead: true),
                PreferenceBinding(builtIn, "SecondClickThreshold", ["light": .int(0), "medium": .int(1), "firm": .int(2)], isOptionalOnRead: true),
            ]),
            effect: .logout
        ),
        .choice("trackpad.quiet-click", "Quiet clicking", "Make the click feel softer and sound quieter.",
                in: .trackpad, "Point and Click", builtIn, "ActuationStrength",
                [("off", "Off", .int(1)), ("on", "On", .int(0))], stock: "off", effect: .logout),
        Tweak(
            id: "trackpad.force-click", title: "Force Click and haptic feedback",
            summary: "Press harder for Quick Look, Look Up, and previews.",
            category: .trackpad, section: "Point and Click",
            options: TweakOption.toggle,
            stock: "on",
            mechanism: .preferences([
                PreferenceBinding(builtIn, "ForceSuppressed", ["on": .bool(false), "off": .bool(true)], isOptionalOnRead: true),
                PreferenceBinding(.global, "com.apple.trackpad.forceClick", ["on": .bool(true), "off": .bool(false)], isOptionalOnRead: true),
            ]),
            effect: .logout
        ),
        trackpad("look-up", "Look up with a three-finger tap", "Tap a word with three fingers to define it.", "Point and Click",
                 "TrackpadThreeFingerTapGesture", offOn(2), stock: "off"),
        trackpad("ignore-with-mouse", "Ignore the trackpad when a mouse is connected", "Turn off the built-in trackpad while you use a mouse.",
                 "Point and Click", "USBMouseStopsTrackpad", offOn(1), stock: "off"),

        // Dragging
        trackpad("tap-drag", "Drag with a double tap", "Double-tap and hold to drag something.", "Dragging", "Dragging", offOn, stock: "off"),
        trackpad("drag-lock", "Drag lock", "Keep dragging after you lift your finger, until you tap again.", "Dragging", "DragLock", offOn, stock: "off"),
        trackpad("three-finger-drag", "Three-finger drag", "Move windows and select text by sliding three fingers.", "Dragging",
                 "TrackpadThreeFingerDrag", offOn, stock: "off"),

        // Scroll and zoom
        .choice("trackpad.natural-scrolling", "Natural scrolling", "Content follows your fingers. Also applies to a mouse wheel.",
                in: .trackpad, "Scroll and Zoom", .global, "com.apple.swipescrolldirection", offOn, stock: "on", effect: .logout),
        trackpad("scrolling", "Two-finger scrolling", "Scroll by sliding two fingers.", "Scroll and Zoom", "TrackpadScroll", offOn, stock: "on"),
        trackpad("horizontal-scrolling", "Horizontal scrolling", "Scroll sideways as well as up and down.", "Scroll and Zoom",
                 "TrackpadHorizScroll", offOn, stock: "on"),
        trackpad("inertia", "Scroll with inertia", "Keep gliding for a moment after you lift your fingers.", "Scroll and Zoom",
                 "TrackpadMomentumScroll", offOn, stock: "on"),
        trackpad("pinch", "Pinch to zoom", "Zoom in and out with two fingers.", "Scroll and Zoom", "TrackpadPinch", offOn, stock: "on"),
        trackpad("smart-zoom", "Smart zoom", "Double-tap with two fingers to zoom in on what's under them.", "Scroll and Zoom",
                 "TrackpadTwoFingerDoubleTapGesture", offOn(1), stock: "on"),
        trackpad("rotate", "Rotate", "Turn photos and pages with two fingers.", "Scroll and Zoom", "TrackpadRotate", offOn, stock: "on"),
        trackpad("notification-center", "Swipe for Notification Center", "Swipe in from the right edge with two fingers.", "Scroll and Zoom",
                 "TrackpadTwoFingerFromRightEdgeSwipeGesture", offOn(3), stock: "on"),

        // Mouse
        .slider("mouse.speed", "Tracking speed", "How far the pointer moves when you move the mouse.",
                in: .trackpad, "Mouse", .global, "com.apple.mouse.scaling",
                NumberInput(0...3, step: 0.125, unit: "×"), stock: 1, effect: .logout),
        .toggle("mouse.acceleration", "Pointer acceleration", "Move farther when you move the mouse faster. Turn off for a steady 1:1 feel.",
                in: .trackpad, "Mouse", .global, "com.apple.mouse.linear", stock: true, on: .bool(false), off: .bool(true), effect: .logout),
        .slider("mouse.scroll-speed", "Scrolling speed", "How far a turn of the wheel scrolls.",
                in: .trackpad, "Mouse", .global, "com.apple.scrollwheel.scaling",
                NumberInput(0.125...1.5, step: 0.0625, unit: "×"), stock: 0.3125, effect: .logout),
        .slider("mouse.double-click", "Double-click speed", "The longest gap between two clicks that still counts as a double-click.",
                in: .trackpad, "Mouse", .global, "com.apple.mouse.doubleClickThreshold",
                NumberInput(0.15...2, step: 0.05, unit: " s"), stock: 0.5, effect: .logout),
        Tweak(
            id: "mouse.magic-secondary", title: "Magic Mouse secondary click",
            summary: "Which side of a Magic Mouse right-clicks.",
            category: .trackpad, section: "Mouse",
            options: [TweakOption("off", "Off"), TweakOption("right", "Click Right Side"), TweakOption("left", "Click Left Side")],
            stock: "off",
            mechanism: .preferences(["com.apple.AppleMultitouchMouse", "com.apple.driver.AppleBluetoothMultitouch.mouse"].map {
                PreferenceBinding(.app($0), "MouseButtonMode", [
                    "off": .string("OneButton"), "right": .string("TwoButton"), "left": .string("TwoButtonSwapped"),
                ], isOptionalOnRead: true)
            }),
            effect: .logout
        ),
    ]

    static let keyboardMore: [Tweak] = [
        .choice("keyboard.globe", "Press the Globe key to", "What the Globe (fn) key does when pressed alone.",
                in: .keyboard, "Keys", .app("com.apple.HIToolbox"), "AppleFnUsageType",
                [("nothing", "Do Nothing", .int(0)), ("input", "Change Input Source", .int(1)),
                 ("emoji", "Show Emoji & Symbols", .int(2)), ("dictation", "Start Dictation", .int(3))],
                stock: "emoji", effect: .logout),
        .toggle("keyboard.function-keys", "Use F1, F2 as standard function keys",
                "The top row sends F1–F12. Hold Globe for brightness and volume.",
                in: .keyboard, "Keys", .global, "com.apple.keyboard.fnState", stock: false, effect: .logout),
        .choice("keyboard.navigation", "Keyboard navigation", "Use Tab to move between every button and control.",
                in: .keyboard, "Keys", .global, "AppleKeyboardUIMode",
                [("off", "Off", .int(0)), ("on", "On", .int(2))], stock: "off"),
        .toggle("keyboard.input-popup", "Input source indicator", "Show a small label by the cursor when the keyboard layout changes.",
                in: .keyboard, "Keys", .global, "TSMLanguageIndicatorEnabled", stock: true, effect: .logout),
        .choice("keyboard.caps-lock-input", "Caps Lock switches input source", "Tap Caps Lock to switch to and from a Latin keyboard.",
                in: .keyboard, "Keys", .global, "TISRomanSwitchState", [("off", "Off", .int(0)), ("on", "On", .int(1))],
                stock: "off", effect: .logout),

        .toggle("text.inline-prediction", "Inline predictive text", "Suggest the rest of a word or sentence in gray as you type.",
                in: .keyboard, "Typing", .global, "NSAutomaticInlinePredictionEnabled", stock: true, effect: .appRelaunch),
        .toggle("text.completion", "Typing suggestions", "Offer word completions as you type.",
                in: .keyboard, "Typing", .global, "NSAutomaticTextCompletionEnabled", stock: true, effect: .appRelaunch),
        .toggle("text.spell-check", "Check spelling while typing", "Underline misspelled words in every app.",
                in: .keyboard, "Typing", .global, "NSAllowContinuousSpellChecking", stock: true, effect: .appRelaunch),
        .toggle("text.detect-language", "Detect the spelling language", "Work out which language you're writing in.",
                in: .keyboard, "Typing", .global, "NSSpellCheckerAutomaticallyIdentifiesLanguages", stock: true, effect: .appRelaunch),
        .choice("text.drag-delay", "Text drag delay", "How long to hold selected text before it can be dragged.",
                in: .keyboard, "Typing", .global, "NSDragAndDropTextDelay",
                [("standard", "Standard", .int(500)), ("short", "Short", .int(100)), ("none", "None", .int(0)),
                 ("disabled", "Never Drag Text", .int(-1))],
                stock: "standard", effect: .appRelaunch),

        // Web views: Safari and apps built on it keep their own copies.
        .toggle("web.spelling", "Check spelling", "Underline misspelled words in web pages.",
                in: .keyboard, "Typing in Web Pages", .global, "WebContinuousSpellCheckingEnabled", stock: true, effect: .appRelaunch),
        .toggle("web.autocorrect", "Correct spelling", "Fix misspelled words in web pages.",
                in: .keyboard, "Typing in Web Pages", .global, "WebAutomaticSpellingCorrectionEnabled", stock: true, effect: .appRelaunch),
        .toggle("web.grammar", "Check grammar", "Underline grammar mistakes in web pages.",
                in: .keyboard, "Typing in Web Pages", .global, "WebGrammarCheckingEnabled", stock: false, effect: .appRelaunch),
        .toggle("web.smart-quotes", "Smart quotes", "Curl straight quotes in web pages.",
                in: .keyboard, "Typing in Web Pages", .global, "WebAutomaticQuoteSubstitutionEnabled", stock: true, effect: .appRelaunch),
        .toggle("web.smart-dashes", "Smart dashes", "Join two hyphens into a dash in web pages.",
                in: .keyboard, "Typing in Web Pages", .global, "WebAutomaticDashSubstitutionEnabled", stock: true, effect: .appRelaunch),
        .toggle("web.text-replacement", "Text replacement", "Expand your shortcuts in web pages.",
                in: .keyboard, "Typing in Web Pages", .global, "WebAutomaticTextReplacementEnabled", stock: true, effect: .appRelaunch),
    ]
}
