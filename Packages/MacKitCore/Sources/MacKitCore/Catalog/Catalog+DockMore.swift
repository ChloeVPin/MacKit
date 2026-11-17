import Foundation

private let dockDomain = PreferenceDomain.app("com.apple.dock")

extension Catalog {
    static let dockMore: [Tweak] = [
        // Appearance
        .slider(
            "dock.size", "Icon size",
            "How big Dock icons are. The Dock shrinks them if they don't fit.",
            in: .dock, "Appearance", dockDomain, "tilesize",
            NumberInput(16...128, step: 1, isInteger: true), stock: 48, effect: .restarts(.dock)
        ),
        .toggle(
            "dock.magnification", "Magnification",
            "Enlarge icons as the pointer passes over them.",
            in: .dock, "Appearance", dockDomain, "magnification", stock: false, effect: .restarts(.dock)
        ),
        .slider(
            "dock.magnified-size", "Magnified size",
            "How big icons grow when magnification is on.",
            in: .dock, "Appearance", dockDomain, "largesize",
            NumberInput(16...128, step: 1, isInteger: true), stock: 64, effect: .restarts(.dock)
        ),
        .toggle(
            "dock.indicators", "Open-app dots",
            "A dot under each app that is running.",
            in: .dock, "Appearance", dockDomain, "show-process-indicators", stock: true, effect: .restarts(.dock)
        ),
        .slider(
            "dock.recent-count", "Number of recent apps",
            "How many apps the recent section holds.",
            in: .dock, "Appearance", dockDomain, "show-recent-count",
            NumberInput(1...15, step: 1, isInteger: true), stock: 3, effect: .restarts(.dock)
        ),
        .toggle(
            "dock.only-open-apps", "Show only open apps",
            "Hide every pinned app and folder, leaving just what's running.",
            in: .dock, "Appearance", dockDomain, "static-only", stock: false, effect: .restarts(.dock),
            caution: "Your pinned apps come back when you turn this off. If they don't, log out and back in."
        ),

        // Windows and apps
        .toggle(
            "dock.attention-bounce", "Bounce for attention",
            "Let an app bounce its icon when it needs you.",
            in: .dock, "Windows and Apps", dockDomain, "no-bouncing", stock: true,
            on: .bool(false), off: .bool(true), effect: .restarts(.dock)
        ),
        .toggle(
            "dock.spring-loading", "Spring-load every Dock item",
            "Hold a dragged file over any Dock icon to open it.",
            in: .dock, "Windows and Apps", dockDomain, "enable-spring-load-actions-on-all-items", stock: false,
            effect: .restarts(.dock)
        ),
        .toggle(
            "dock.stack-highlight", "Highlight items in stacks",
            "Highlight the item under the pointer in a grid stack.",
            in: .dock, "Windows and Apps", dockDomain, "mouse-over-hilite-stack", stock: false, effect: .restarts(.dock)
        ),
        .toggle(
            "dock.slow-motion", "Slow motion with Shift",
            "Hold Shift to play Dock animations slowly.",
            in: .dock, "Windows and Apps", dockDomain, "slow-motion-allowed", stock: false, effect: .restarts(.dock)
        ),
        .toggle(
            "dock.switcher-all-displays", "App switcher on every display",
            "Show the Command-Tab switcher on all screens, not just one.",
            in: .dock, "Windows and Apps", dockDomain, "appswitcher-all-displays", stock: false, effect: .restarts(.dock)
        ),

        // Lock
        .toggle(
            "dock.lock-contents", "Lock contents",
            "Stop icons being added, removed, or rearranged.",
            in: .dock, "Lock the Dock", dockDomain, "contents-immutable", stock: false, effect: .restarts(.dock)
        ),
        .toggle(
            "dock.lock-size", "Lock size",
            "Stop the Dock being resized by dragging its divider.",
            in: .dock, "Lock the Dock", dockDomain, "size-immutable", stock: false, effect: .restarts(.dock)
        ),
        .toggle(
            "dock.lock-position", "Lock position",
            "Stop the Dock being moved to another screen edge.",
            in: .dock, "Lock the Dock", dockDomain, "position-immutable", stock: false, effect: .restarts(.dock)
        ),
        .toggle(
            "dock.lock-magnification", "Lock magnification",
            "Stop the magnification setting being changed.",
            in: .dock, "Lock the Dock", dockDomain, "magnify-immutable", stock: false, effect: .restarts(.dock)
        ),
        .toggle(
            "dock.lock-autohide", "Lock automatic hiding",
            "Stop the hide setting being changed.",
            in: .dock, "Lock the Dock", dockDomain, "autohide-immutable", stock: false, effect: .restarts(.dock)
        ),
        .toggle(
            "dock.lock-minimize-effect", "Lock the minimize effect",
            "Stop the minimize effect being changed.",
            in: .dock, "Lock the Dock", dockDomain, "mineffect-immutable", stock: false, effect: .restarts(.dock)
        ),
    ]

    static let windowsMore: [Tweak] = [
        .choice(
            "windows.title-double-click", "Double-click a title bar to",
            "What happens when you double-click the top of a window.",
            in: .windows, "Behavior", .global, "AppleActionOnDoubleClick",
            [
                ("zoom", "Zoom", .string("Maximize")), ("fill", "Fill", .string("Fill")),
                ("minimize", "Minimize", .string("Minimize")), ("nothing", "Do Nothing", .string("None")),
            ],
            stock: "zoom", effect: .appRelaunch
        ),
        .choice(
            "windows.tabs", "Prefer tabs",
            "When apps open documents in tabs instead of separate windows.",
            in: .windows, "Documents", .global, "AppleWindowTabbingMode",
            [
                ("never", "Never", .string("manual")), ("fullscreen", "In Full Screen", .string("fullscreen")),
                ("always", "Always", .string("always")),
            ],
            stock: "fullscreen", effect: .appRelaunch
        ),
        .toggle(
            "windows.drag-anywhere", "Drag windows from anywhere",
            "Hold Control and Command, then drag any part of a window.",
            in: .windows, "Behavior", .global, "NSWindowShouldDragOnGesture", stock: false, effect: .appRelaunch
        ),
        .toggle(
            "windows.animations", "Opening and closing animations",
            "Animate windows as they open and close.",
            in: .windows, "Behavior", .global, "NSAutomaticWindowAnimationsEnabled", stock: true, effect: .appRelaunch
        ),
        .choice(
            "windows.resize-speed", "Resize animation",
            "How fast windows animate to a new size, such as when zooming.",
            in: .windows, "Behavior", .global, "NSWindowResizeTime",
            [("standard", "Standard", .double(0.2)), ("fast", "Fast", .double(0.1)), ("instant", "Instant", .double(0.001))],
            stock: "standard", effect: .appRelaunch
        ),

        // Tiling
        .toggle(
            "tiling.edge-drag", "Tile by dragging to screen edges",
            "Drag a window to the left or right edge to fill half the screen.",
            in: .windows, "Tiling", .app("com.apple.WindowManager"), "EnableTilingByEdgeDrag", stock: true,
            effect: .restarts(.windowManager)
        ),
        .toggle(
            "tiling.top-drag", "Fill by dragging to the menu bar",
            "Drag a window to the top of the screen to fill it.",
            in: .windows, "Tiling", .app("com.apple.WindowManager"), "EnableTopTilingByEdgeDrag", stock: true,
            effect: .restarts(.windowManager)
        ),
        .toggle(
            "tiling.option-drag", "Tile while holding Option",
            "Hold Option while dragging to tile without reaching the edge.",
            in: .windows, "Tiling", .app("com.apple.WindowManager"), "EnableTilingOptionAccelerator", stock: true,
            effect: .restarts(.windowManager)
        ),
        .toggle(
            "tiling.margins", "Gaps around tiled windows",
            "Leave a margin between tiled windows and the screen edges.",
            in: .windows, "Tiling", .app("com.apple.WindowManager"), "EnableTiledWindowMargins", stock: true,
            effect: .restarts(.windowManager)
        ),
    ]
}
