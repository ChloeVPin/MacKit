import Foundation

private let finderDomain = PreferenceDomain.app("com.apple.finder")

extension Catalog {
    static let finderMore: [Tweak] = [
        // Windows
        .choice(
            "finder.new-window", "New windows show",
            "The folder a new Finder window opens to.",
            in: .finder, "Windows", finderDomain, "NewWindowTarget",
            [
                ("recents", "Recents", .string("PfAF")), ("home", "Home", .string("PfHm")),
                ("desktop", "Desktop", .string("PfDe")), ("documents", "Documents", .string("PfDo")),
                ("icloud", "iCloud Drive", .string("PfID")), ("computer", "Computer", .string("PfCm")),
                ("disk", "Startup Disk", .string("PfVo")),
            ],
            stock: "recents", effect: .restarts(.finder)
        ),
        .toggle(
            "finder.tabs", "Open folders in tabs",
            "Command-double-click opens a tab. Turn off for a new window.",
            in: .finder, "Windows", finderDomain, "FinderSpawnTab", stock: true, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.path-in-title", "Full path in the title",
            "Show the whole folder path as the window title.",
            in: .finder, "Windows", finderDomain, "_FXShowPosixPathInTitle", stock: false, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.path-from-home", "Path bar starts at Home",
            "Leave the disk and Users folders out of the path bar.",
            in: .finder, "Windows", finderDomain, "PathBarRootAtHome", stock: false, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.sidebar", "Sidebar",
            "The list of favorites and locations in each window.",
            in: .finder, "Windows", finderDomain, "ShowSidebar", stock: true, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.preview-pane", "Preview pane",
            "A large preview of the selected file, on the right.",
            in: .finder, "Windows", finderDomain, "ShowPreviewPane", stock: false, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.tab-bar", "Always show the tab bar",
            "Keep the tab bar visible with a single tab.",
            in: .finder, "Windows", finderDomain, "ShowTabView", stock: false, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.recent-tags", "Recent tags in the sidebar",
            "List the tags you used lately under Tags.",
            in: .finder, "Windows", finderDomain, "ShowRecentTags", stock: true, effect: .restarts(.finder)
        ),
        .choice(
            "finder.sidebar-size", "Sidebar icon size",
            "The size of sidebar icons and text, in Finder and other apps.",
            in: .finder, "Windows", .global, "NSTableViewDefaultSizeMode",
            [("small", "Small", .int(1)), ("medium", "Medium", .int(2)), ("large", "Large", .int(3))],
            stock: "medium", effect: .appRelaunch
        ),
        .choice(
            "finder.group-by", "Group items by",
            "How new windows group their contents.",
            in: .finder, "Windows", finderDomain, "FXPreferredGroupBy",
            [
                ("none", "None", .string("None")), ("name", "Name", .string("Name")), ("kind", "Kind", .string("Kind")),
                ("application", "Application", .string("Application")),
                ("opened", "Date Last Opened", .string("Date Last Opened")),
                ("added", "Date Added", .string("Date Added")), ("modified", "Date Modified", .string("Date Modified")),
                ("created", "Date Created", .string("Date Created")), ("size", "Size", .string("Size")),
                ("tags", "Tags", .string("Tags")),
            ],
            stock: "none", effect: .restarts(.finder)
        ),
        .slider(
            "finder.title-icon-delay", "Title icon delay",
            "How long to hover over a window title before its folder icon appears.",
            in: .finder, "Windows", .global, "NSToolbarTitleViewRolloverDelay",
            NumberInput(0...1, step: 0.05, unit: " s"), stock: 0.5, effect: .appRelaunch
        ),

        // Files
        .toggle(
            "finder.quit", "Allow quitting Finder",
            "Add Quit to the Finder menu. Desktop icons hide while Finder is closed.",
            in: .finder, "Files", finderDomain, "QuitMenuItem", stock: false, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.icloud-warning", "Warn before removing from iCloud Drive",
            "Ask first when moving a file out of iCloud Drive.",
            in: .finder, "Files", finderDomain, "FXEnableRemoveFromICloudDriveWarning", stock: true, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.spring-loading", "Spring-loaded folders",
            "Hold a dragged file over a folder to open it.",
            in: .finder, "Files", .global, "com.apple.springing.enabled", stock: true, effect: .restarts(.finder)
        ),
        .slider(
            "finder.spring-delay", "Spring-loading delay",
            "How long to hold before the folder opens.",
            in: .finder, "Files", .global, "com.apple.springing.delay",
            NumberInput(0...2, step: 0.05, unit: " s"), stock: 0.5, effect: .restarts(.finder)
        ),

        // Trash
        .toggle(
            "finder.trash-warning", "Warn before emptying the Trash",
            "Ask for confirmation before deleting everything in the Trash.",
            in: .finder, "Trash", finderDomain, "WarnOnEmptyTrash", stock: true, effect: .restarts(.finder),
            caution: "With this off, Empty Trash deletes everything at once, with no second chance."
        ),
        .toggle(
            "finder.trash-30-days", "Empty the Trash after 30 days",
            "Delete items that have been in the Trash for a month.",
            in: .finder, "Trash", finderDomain, "FXRemoveOldTrashItems", stock: false, effect: .restarts(.finder),
            caution: "Files are deleted for good without asking, 30 days after you trash them."
        ),

        // Animation and sound
        .toggle(
            "finder.animations", "Animations",
            "Window and Get Info animations in Finder.",
            in: .finder, "Animation and Sound", finderDomain, "DisableAllAnimations", stock: true,
            on: .bool(false), off: .bool(true), effect: .restarts(.finder)
        ),
        .toggle(
            "finder.info-animation", "Animate Get Info sections",
            "Slide sections open and closed in Get Info windows.",
            in: .finder, "Animation and Sound", finderDomain, "AnimateInfoPanes", stock: true, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.zoom-animation", "Animate opening folders",
            "Zoom windows out of the icon you opened.",
            in: .finder, "Animation and Sound", finderDomain, "AnimateWindowZoom", stock: true, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.grid-animation", "Animate snapping to the grid",
            "Slide icons into place when they line up.",
            in: .finder, "Animation and Sound", finderDomain, "AnimateSnapToGrid", stock: true, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.slow-motion", "Slow motion with Shift",
            "Hold Shift to play Finder animations slowly.",
            in: .finder, "Animation and Sound", finderDomain, "FXEnableSlowAnimation", stock: false, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.sounds", "Sound effects",
            "The sounds for moving files to the Trash and emptying it.",
            in: .finder, "Animation and Sound", finderDomain, "FinderSounds", stock: true, effect: .restarts(.finder)
        ),
        .choice(
            "finder.quick-look-speed", "Quick Look animation",
            "How fast the preview opens when you press Space.",
            in: .finder, "Animation and Sound", .global, "QLPanelAnimationDuration",
            [("standard", "Standard", .double(0.2)), ("fast", "Fast", .double(0.1)), ("instant", "Instant", .double(0))],
            stock: "standard", effect: .restarts(.finder)
        ),

        // Network
        .toggle(
            "finder.network-wait", "Load network folders in one go",
            "Wait for the whole folder before showing anything.",
            in: .finder, "External Drives", .app("com.apple.desktopservices"), "UseBareEnumeration", stock: false,
            effect: .restarts(.finder)
        ),
        .toggle(
            "finder.airdrop", "AirDrop",
            "Send and receive files with nearby Apple devices.",
            in: .finder, "External Drives", .app("com.apple.NetworkBrowser"), "DisableAirDrop", stock: true,
            on: .bool(false), off: .bool(true), effect: .logout
        ),

        // Restrictions
        .toggle(
            "finder.block-connect", "Block Connect to Server",
            "Disable the Connect to Server command in Finder.",
            in: .finder, "Restrictions", finderDomain, "ProhibitConnectTo", stock: false, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.block-go-to-folder", "Block Go to Folder",
            "Disable the Go to Folder command in Finder.",
            in: .finder, "Restrictions", finderDomain, "ProhibitGoToFolder", stock: false, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.block-eject", "Block ejecting disks",
            "Turn off the Eject command in Finder.",
            in: .finder, "Restrictions", finderDomain, "ProhibitEject", stock: false, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.block-empty-trash", "Block emptying the Trash",
            "Turn off Empty Trash, so nothing is deleted by accident.",
            in: .finder, "Restrictions", finderDomain, "ProhibitEmptyTrash", stock: false, effect: .restarts(.finder)
        ),
    ]
}
