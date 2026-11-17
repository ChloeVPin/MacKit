import Foundation

private let dockDomain = PreferenceDomain.app("com.apple.dock")

extension Catalog {
    static let missionControl: [Tweak] = [
        // Mission Control
        .toggle(
            "mission.group-apps", "Group windows by app",
            "Stack each app's windows together in Mission Control.",
            in: .missionControl, "Mission Control", dockDomain, "expose-group-apps", stock: false, effect: .restarts(.dock)
        ),
        .toggle(
            "mission.top-drag", "Drag to the top for Mission Control",
            "Dragging a window to the top of the screen opens Mission Control.",
            in: .missionControl, "Mission Control", dockDomain, "enterMissionControlByTopWindowDrag", stock: true,
            effect: .restarts(.dock)
        ),
        .toggle(
            "mission.disable", "Mission Control",
            "Turn off to remove Mission Control, App Exposé, and Show Desktop.",
            in: .missionControl, "Mission Control", dockDomain, "mcx-expose-disabled", stock: true,
            on: .bool(false), off: .bool(true), effect: .restarts(.dock)
        ),

        // Spaces
        .toggle(
            "mission.switch-space", "Switch to an app's Space",
            "Opening an app jumps to the desktop its windows are on.",
            in: .missionControl, "Spaces", .global, "AppleSpacesSwitchOnActivate", stock: true, effect: .restarts(.dock)
        ),
        .toggle(
            "mission.separate-spaces", "Displays have separate Spaces",
            "Each display gets its own desktops, menu bar, and Dock.",
            in: .missionControl, "Spaces", .app("com.apple.spaces"), "spans-displays", stock: true,
            on: .bool(false), off: .bool(true), effect: .logout
        ),
        .slider(
            "mission.edge-delay", "Drag to the next Space",
            "How long to hold a window at the screen edge before it moves over.",
            in: .missionControl, "Spaces", dockDomain, "workspaces-edge-delay",
            NumberInput(0...3, step: 0.05, unit: " s"), stock: 0.75, effect: .restarts(.dock)
        ),

        // Gestures
        .toggle(
            "mission.gesture", "Swipe up for Mission Control",
            "The trackpad gesture that shows every open window.",
            in: .missionControl, "Gestures", dockDomain, "showMissionControlGestureEnabled", stock: true,
            effect: .restarts(.dock)
        ),
        .toggle(
            "mission.expose-gesture", "Swipe down for App Exposé",
            "The trackpad gesture that shows the current app's windows.",
            in: .missionControl, "Gestures", dockDomain, "showAppExposeGestureEnabled", stock: false, effect: .restarts(.dock)
        ),
        .toggle(
            "mission.desktop-gesture", "Spread to show the desktop",
            "Spread your thumb and three fingers to move windows aside.",
            in: .missionControl, "Gestures", dockDomain, "showDesktopGestureEnabled", stock: true, effect: .restarts(.dock)
        ),
    ] + hotCorners

    private static let hotCorners: [Tweak] = [
        ("tl", "Top left", "disabled"), ("tr", "Top right", "disabled"),
        ("bl", "Bottom left", "disabled"), ("br", "Bottom right", "quick-note"),
    ].flatMap { corner, name, stock -> [Tweak] in
        [
            .choice(
                "corner.\(corner)", name,
                "What happens when the pointer reaches this corner.",
                in: .missionControl, "Hot Corners", dockDomain, "wvous-\(corner)-corner",
                [
                    ("disabled", "Nothing", .int(1)), ("mission-control", "Mission Control", .int(2)),
                    ("app-windows", "Application Windows", .int(3)), ("desktop", "Desktop", .int(4)),
                    ("notification-center", "Notification Center", .int(12)),
                    ("quick-note", "Quick Note", .int(14)), ("screen-saver", "Start Screen Saver", .int(5)),
                    ("no-screen-saver", "Disable Screen Saver", .int(6)), ("display-sleep", "Put Display to Sleep", .int(10)),
                    ("lock", "Lock Screen", .int(13)),
                ],
                stock: stock, effect: .restarts(.dock)
            ),
            .choice(
                "corner.\(corner)-key", "\(name) needs a key",
                "Only trigger this corner while a key is held.",
                in: .missionControl, "Hot Corners", dockDomain, "wvous-\(corner)-modifier",
                [
                    ("none", "No Key", .int(0)), ("shift", "Shift", .int(131_072)), ("control", "Control", .int(262_144)),
                    ("option", "Option", .int(524_288)), ("command", "Command", .int(1_048_576)),
                ],
                stock: "none", effect: .restarts(.dock)
            ),
        ]
    }
}
