import Foundation

extension Catalog {
    // MARK: Keyboard

    static let keyboard: [Tweak] = [
        .toggle(
            "keyboard.press-and-hold", "Accent menu on key hold",
            "Turn off to make held keys repeat instead.",
            in: .keyboard, "Keys", .global, "ApplePressAndHoldEnabled", stock: true, effect: .appRelaunch
        ),
        Tweak(
            id: "keyboard.repeat-rate", title: "Key repeat",
            summary: "How fast a held key repeats. Fastest goes beyond System Settings.",
            category: .keyboard, section: "Keys",
            options: [TweakOption("standard", "Standard"), TweakOption("fast", "Fast"), TweakOption("fastest", "Fastest")],
            stock: "standard",
            mechanism: .preferences([
                PreferenceBinding(.global, "KeyRepeat", ["standard": .int(6), "fast": .int(2), "fastest": .int(1)])
            ]),
            effect: .logout
        ),
        Tweak(
            id: "keyboard.repeat-delay", title: "Delay until repeat",
            summary: "How long to hold a key before it repeats.",
            category: .keyboard, section: "Keys",
            options: [TweakOption("standard", "Standard"), TweakOption("short", "Short"), TweakOption("shortest", "Shortest")],
            stock: "standard",
            mechanism: .preferences([
                PreferenceBinding(.global, "InitialKeyRepeat", ["standard": .int(25), "short": .int(15), "shortest": .int(10)])
            ]),
            effect: .logout
        ),
        .toggle(
            "text.autocorrect", "Correct spelling",
            "Replace misspelled words as you type.",
            in: .keyboard, "Typing", .global, "NSAutomaticSpellingCorrectionEnabled", stock: true, effect: .appRelaunch
        ),
        .toggle(
            "text.capitalize", "Capitalize sentences",
            "Capitalize the first word of each sentence.",
            in: .keyboard, "Typing", .global, "NSAutomaticCapitalizationEnabled", stock: true, effect: .appRelaunch
        ),
        .toggle(
            "text.period", "Period with double space",
            "Two spaces insert a period.",
            in: .keyboard, "Typing", .global, "NSAutomaticPeriodSubstitutionEnabled", stock: true, effect: .appRelaunch
        ),
        .toggle(
            "text.smart-quotes", "Smart quotes",
            "Curl straight quotes. Turn off if you paste into code.",
            in: .keyboard, "Typing", .global, "NSAutomaticQuoteSubstitutionEnabled", stock: true, effect: .appRelaunch
        ),
        .toggle(
            "text.smart-dashes", "Smart dashes",
            "Join two hyphens into a dash. Turn off for command-line flags.",
            in: .keyboard, "Typing", .global, "NSAutomaticDashSubstitutionEnabled", stock: true, effect: .appRelaunch
        ),
    ]
}
