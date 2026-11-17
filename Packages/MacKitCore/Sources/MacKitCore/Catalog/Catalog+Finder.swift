import Foundation

extension Catalog {
    // MARK: Finder

    static let finder: [Tweak] = [
        .toggle(
            "finder.hidden-files", "Show hidden files",
            "Files whose names start with a dot, like .gitignore.",
            in: .finder, "Files", .app("com.apple.finder"), "AppleShowAllFiles", stock: false, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.extensions", "Show filename extensions",
            "Always show endings like .pdf and .png.",
            in: .finder, "Files", .global, "AppleShowAllExtensions", stock: false, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.extension-warning", "Warn before changing an extension",
            "Ask first when a rename would change the file type.",
            in: .finder, "Files", .app("com.apple.finder"), "FXEnableExtensionChangeWarning", stock: true, effect: .restarts(.finder)
        ),
        Tweak(
            id: "finder.library", title: "Show the Library folder",
            summary: "Where apps keep their settings, in your home folder.",
            category: .finder, section: "Files",
            options: TweakOption.toggle,
            stock: "off",
            mechanism: .libraryVisibility
        ),
        .toggle(
            "finder.path-bar", "Path bar",
            "The current folder's location, along the bottom of the window.",
            in: .finder, "Windows", .app("com.apple.finder"), "ShowPathbar", stock: false, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.status-bar", "Status bar",
            "Item count and free space, along the bottom of the window.",
            in: .finder, "Windows", .app("com.apple.finder"), "ShowStatusBar", stock: false, effect: .restarts(.finder)
        ),
        .toggle(
            "finder.folders-first", "Keep folders on top",
            "List folders before files when sorting by name.",
            in: .finder, "Windows", .app("com.apple.finder"), "_FXSortFoldersFirst", stock: false, effect: .restarts(.finder)
        ),
        Tweak(
            id: "finder.default-view", title: "Default view",
            summary: "How new windows open. Folders you've arranged keep their view.",
            category: .finder, section: "Windows",
            options: [
                TweakOption("icon", "Icons"), TweakOption("list", "List"),
                TweakOption("column", "Columns"), TweakOption("gallery", "Gallery"),
            ],
            stock: "icon",
            mechanism: .preferences([
                PreferenceBinding(.app("com.apple.finder"), "FXPreferredViewStyle", [
                    "icon": .string("icnv"), "list": .string("Nlsv"),
                    "column": .string("clmv"), "gallery": .string("glyv"),
                ])
            ]),
            effect: .restarts(.finder)
        ),
        Tweak(
            id: "finder.search-scope", title: "Search in",
            summary: "Where Finder looks when you search from a window.",
            category: .finder, section: "Windows",
            options: [
                TweakOption("mac", "This Mac"), TweakOption("folder", "Current Folder"),
                TweakOption("previous", "Last Used"),
            ],
            stock: "mac",
            mechanism: .preferences([
                PreferenceBinding(.app("com.apple.finder"), "FXDefaultSearchScope", [
                    "mac": .string("SCev"), "folder": .string("SCcf"), "previous": .string("SCsp"),
                ])
            ]),
            effect: .restarts(.finder)
        ),
        .toggle(
            "finder.ds-store-network", "Keep network drives clean",
            "Don't leave hidden .DS_Store files on shared volumes.",
            in: .finder, "External Drives", .app("com.apple.desktopservices"), "DSDontWriteNetworkStores", stock: false, effect: .logout
        ),
        .toggle(
            "finder.ds-store-usb", "Keep USB drives clean",
            "Don't leave hidden .DS_Store files on external drives.",
            in: .finder, "External Drives", .app("com.apple.desktopservices"), "DSDontWriteUSBStores", stock: false, effect: .logout
        ),
    ]
}
