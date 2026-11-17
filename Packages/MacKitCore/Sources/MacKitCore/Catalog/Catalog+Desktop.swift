import Foundation

private let finderDomain = PreferenceDomain.app("com.apple.finder")
private let windowManager = PreferenceDomain.app("com.apple.WindowManager")
private let desktopView = ["DesktopViewSettings"]
private let desktopIcons = ["DesktopViewSettings", "IconViewSettings"]

extension Catalog {
    static let desktop: [Tweak] = [
        // Desktop
        .toggle(
            "desktop.items", "Show items on the desktop",
            "Files and folders you keep on the desktop.",
            in: .desktop, "Desktop", windowManager, "StandardHideDesktopIcons", stock: true,
            on: .bool(false), off: .bool(true), effect: .restarts(.windowManager)
        ),
        .toggle(
            "desktop.widgets", "Show widgets on the desktop",
            "Widgets you've placed on the desktop.",
            in: .desktop, "Desktop", windowManager, "StandardHideWidgets", stock: true,
            on: .bool(false), off: .bool(true), effect: .restarts(.windowManager)
        ),
        .choice(
            "desktop.click-wallpaper", "Click wallpaper to show desktop",
            "Clicking the wallpaper moves every window aside.",
            in: .desktop, "Desktop", windowManager, "EnableStandardClickToShowDesktop",
            [("always", "Always", .bool(true)), ("stage-manager", "Only in Stage Manager", .bool(false))],
            stock: "always", effect: .restarts(.windowManager)
        ),
        .toggle(
            "desktop.finder-draws", "Let Finder manage the desktop",
            "Turn off for a completely empty desktop: no icons, no right-click menu.",
            in: .desktop, "Desktop", finderDomain, "CreateDesktop", stock: true, effect: .restarts(.finder),
            caution: "With this off you can't drop files on the desktop or right-click it. The files stay in your Desktop folder."
        ),
        .toggle(
            "desktop.folders-first", "Keep desktop folders on top",
            "Sort folders before files on the desktop.",
            in: .desktop, "Desktop", finderDomain, "_FXSortFoldersFirstOnDesktop", stock: false, effect: .restarts(.finder)
        ),

        // Icons and Stacks
        .choice(
            "desktop.stacks", "Use Stacks by",
            "Group desktop files into tidy stacks by kind, date, or tags.",
            in: .desktop, "Icons and Stacks", finderDomain, path: desktopView, "GroupBy",
            [
                ("none", "Off", .string("None")), ("kind", "Kind", .string("Kind")),
                ("opened", "Date Last Opened", .string("Date Last Opened")),
                ("added", "Date Added", .string("Date Added")), ("modified", "Date Modified", .string("Date Modified")),
                ("created", "Date Created", .string("Date Created")), ("tags", "Tags", .string("Tags")),
            ],
            stock: "none", effect: .restarts(.finder)
        ),
        .choice(
            "desktop.arrange-by", "Sort desktop icons by",
            "How desktop icons stay arranged when Stacks are off.",
            in: .desktop, "Icons and Stacks", finderDomain, path: desktopIcons, "arrangeBy",
            [
                ("none", "None", .string("none")), ("grid", "Snap to Grid", .string("grid")),
                ("name", "Name", .string("name")), ("kind", "Kind", .string("kind")),
                ("opened", "Date Last Opened", .string("dateLastOpened")),
                ("added", "Date Added", .string("dateAdded")), ("modified", "Date Modified", .string("dateModified")),
                ("created", "Date Created", .string("dateCreated")), ("size", "Size", .string("size")),
                ("tags", "Tags", .string("label")),
            ],
            stock: "none", effect: .restarts(.finder)
        ),
        .slider(
            "desktop.icon-size", "Icon size",
            "How large icons appear on the desktop.",
            in: .desktop, "Icons and Stacks", finderDomain, path: desktopIcons, "iconSize",
            NumberInput(16...512, step: 4, unit: " px", isInteger: true), stock: 64, effect: .restarts(.finder)
        ),
        .slider(
            "desktop.grid-spacing", "Grid spacing",
            "How much room sits between icons on the desktop.",
            in: .desktop, "Icons and Stacks", finderDomain, path: desktopIcons, "gridSpacing",
            NumberInput(1...100, step: 1, isInteger: true), stock: 54, effect: .restarts(.finder)
        ),
        .slider(
            "desktop.text-size", "Label text size",
            "The font size of file and folder names on the desktop.",
            in: .desktop, "Icons and Stacks", finderDomain, path: desktopIcons, "textSize",
            NumberInput(10...16, step: 1, unit: " pt", isInteger: true), stock: 12, effect: .restarts(.finder)
        ),
        .choice(
            "desktop.label-position", "Label position",
            "Where each file's name sits next to its icon.",
            in: .desktop, "Icons and Stacks", finderDomain, path: desktopIcons, "labelOnBottom",
            [("bottom", "Bottom", .bool(true)), ("right", "Right", .bool(false))],
            stock: "bottom", effect: .restarts(.finder)
        ),
        .toggle(
            "desktop.item-info", "Show item info",
            "Show item counts under folders and dimensions under images.",
            in: .desktop, "Icons and Stacks", finderDomain, path: desktopIcons, "showItemInfo",
            stock: false, effect: .restarts(.finder)
        ),
        .toggle(
            "desktop.icon-preview", "Show icon previews",
            "Use a thumbnail of each image, PDF, or video as its icon.",
            in: .desktop, "Icons and Stacks", finderDomain, path: desktopIcons, "showIconPreview",
            stock: true, effect: .restarts(.finder)
        ),

        // Disks
        .toggle(
            "desktop.hard-disks", "Hard disks",
            "Show this Mac's built-in disk on the desktop.",
            in: .desktop, "Disks on the Desktop", finderDomain, "ShowHardDrivesOnDesktop", stock: false, effect: .restarts(.finder)
        ),
        .toggle(
            "desktop.external-disks", "External disks",
            "Show USB and Thunderbolt drives on the desktop.",
            in: .desktop, "Disks on the Desktop", finderDomain, "ShowExternalHardDrivesOnDesktop", stock: true,
            effect: .restarts(.finder)
        ),
        .toggle(
            "desktop.removable-media", "CDs, DVDs, and iPods",
            "Show discs and other removable media.",
            in: .desktop, "Disks on the Desktop", finderDomain, "ShowRemovableMediaOnDesktop", stock: true,
            effect: .restarts(.finder)
        ),
        .toggle(
            "desktop.servers", "Connected servers",
            "Show network volumes you're connected to.",
            in: .desktop, "Disks on the Desktop", finderDomain, "ShowMountedServersOnDesktop", stock: false,
            effect: .restarts(.finder)
        ),

        // Stage Manager
        .toggle(
            "stage.enabled", "Stage Manager",
            "Keep one app in the middle and the rest in a strip at the side.",
            in: .desktop, "Stage Manager", windowManager, "GloballyEnabled", stock: false, effect: .restarts(.windowManager)
        ),
        .toggle(
            "stage.recent-apps", "Show recent apps strip",
            "Keep the strip of recent apps visible. Off hides it until you reach the edge.",
            in: .desktop, "Stage Manager", windowManager, "AutoHide", stock: true,
            on: .bool(false), off: .bool(true), effect: .restarts(.windowManager)
        ),
        .choice(
            "stage.grouping", "Show an app's windows",
            "Whether an app brings all of its windows forward or one.",
            in: .desktop, "Stage Manager", windowManager, "AppWindowGroupingBehavior",
            [("all", "All at Once", .int(1)), ("one", "One at a Time", .int(0))],
            stock: "all", effect: .restarts(.windowManager)
        ),
        .toggle(
            "stage.desktop-items", "Show desktop items",
            "Keep desktop files visible while Stage Manager is on.",
            in: .desktop, "Stage Manager", windowManager, "HideDesktop", stock: false,
            on: .bool(false), off: .bool(true), effect: .restarts(.windowManager)
        ),
        .toggle(
            "stage.widgets", "Show widgets",
            "Keep desktop widgets visible while Stage Manager is on.",
            in: .desktop, "Stage Manager", windowManager, "StageManagerHideWidgets", stock: true,
            on: .bool(false), off: .bool(true), effect: .restarts(.windowManager)
        ),
    ]
}
