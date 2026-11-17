import Foundation

extension Catalog {
    // MARK: Dock

    static let dock: [Tweak] = [
        .toggle(
            "dock.autohide", "Hide automatically",
            "Keep the Dock off screen until you move to its edge.",
            in: .dock, "Appearance", .app("com.apple.dock"), "autohide", stock: false, effect: .restarts(.dock)
        ),
        Tweak(
            id: "dock.reveal-speed", title: "Reveal speed",
            summary: "How quickly a hidden Dock slides back in.",
            category: .dock, section: "Appearance",
            options: [
                TweakOption("standard", "Standard"), TweakOption("fast", "Fast"), TweakOption("instant", "Instant"),
            ],
            stock: "standard",
            mechanism: .preferences([
                PreferenceBinding(.app("com.apple.dock"), "autohide-delay", ["fast": .double(0), "instant": .double(0)]),
                PreferenceBinding(.app("com.apple.dock"), "autohide-time-modifier", ["fast": .double(0.4), "instant": .double(0)]),
            ]),
            effect: .restarts(.dock)
        ),
        Tweak(
            id: "dock.position", title: "Position",
            summary: "The screen edge the Dock sits on.",
            category: .dock, section: "Appearance",
            options: [TweakOption("left", "Left"), TweakOption("bottom", "Bottom"), TweakOption("right", "Right")],
            stock: "bottom",
            mechanism: .preferences([
                PreferenceBinding(.app("com.apple.dock"), "orientation", [
                    "left": .string("left"), "bottom": .string("bottom"), "right": .string("right"),
                ])
            ]),
            effect: .restarts(.dock)
        ),
        .toggle(
            "dock.recents", "Show recent apps",
            "A section for apps you opened recently.",
            in: .dock, "Appearance", .app("com.apple.dock"), "show-recents", stock: true, effect: .restarts(.dock)
        ),
        Tweak(
            id: "dock.minimize-effect", title: "Minimize effect",
            summary: "How windows shrink into the Dock. Suck is a hidden third style.",
            category: .dock, section: "Windows and Apps",
            options: [TweakOption("genie", "Genie"), TweakOption("scale", "Scale"), TweakOption("suck", "Suck")],
            stock: "genie",
            mechanism: .preferences([
                PreferenceBinding(.app("com.apple.dock"), "mineffect", [
                    "genie": .string("genie"), "scale": .string("scale"), "suck": .string("suck"),
                ])
            ]),
            effect: .restarts(.dock)
        ),
        .toggle(
            "dock.minimize-to-app", "Minimize into app icon",
            "Tuck minimized windows into the app's own icon.",
            in: .dock, "Windows and Apps", .app("com.apple.dock"), "minimize-to-application", stock: false, effect: .restarts(.dock)
        ),
        .toggle(
            "dock.launch-animation", "Bounce when opening",
            "Animate an app's icon while it starts.",
            in: .dock, "Windows and Apps", .app("com.apple.dock"), "launchanim", stock: true, effect: .restarts(.dock)
        ),
        .toggle(
            "dock.rearrange-spaces", "Rearrange Spaces automatically",
            "Let macOS reorder your desktops by recent use.",
            in: .missionControl, "Spaces", .app("com.apple.dock"), "mru-spaces", stock: true, effect: .restarts(.dock)
        ),
    ]
}
