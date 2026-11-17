import Foundation

extension Catalog {
    // MARK: Windows

    static let windows: [Tweak] = [
        Tweak(
            id: "windows.save-expanded", title: "Expanded save dialogs",
            summary: "Open save dialogs with the full file browser.",
            category: .windows, section: "Dialogs",
            options: TweakOption.toggle,
            stock: "off",
            mechanism: .preferences([
                PreferenceBinding(.global, "NSNavPanelExpandedStateForSaveMode", ["on": .bool(true), "off": .bool(false)], isOptionalOnRead: true),
                PreferenceBinding(.global, "NSNavPanelExpandedStateForSaveMode2", ["on": .bool(true), "off": .bool(false)], isOptionalOnRead: true),
            ]),
            effect: .appRelaunch
        ),
        Tweak(
            id: "windows.print-expanded", title: "Expanded print dialogs",
            summary: "Open print dialogs with every option showing.",
            category: .windows, section: "Dialogs",
            options: TweakOption.toggle,
            stock: "off",
            mechanism: .preferences([
                PreferenceBinding(.global, "PMPrintingExpandedStateForPrint", ["on": .bool(true), "off": .bool(false)], isOptionalOnRead: true),
                PreferenceBinding(.global, "PMPrintingExpandedStateForPrint2", ["on": .bool(true), "off": .bool(false)], isOptionalOnRead: true),
            ]),
            effect: .appRelaunch
        ),
        .toggle(
            "windows.save-to-icloud", "Save new documents to iCloud",
            "Turn off to suggest this Mac instead.",
            in: .windows, "Documents", .global, "NSDocumentSaveNewDocumentsToCloud", stock: true, effect: .appRelaunch
        ),
        .toggle(
            "windows.confirm-close", "Ask to keep changes",
            "Ask before closing a document with unsaved changes.",
            in: .windows, "Documents", .global, "NSCloseAlwaysConfirmsChanges", stock: false, effect: .appRelaunch
        ),
        Tweak(
            id: "windows.scroll-bars", title: "Scroll bars",
            summary: "When scroll bars are visible.",
            category: .windows, section: "Behavior",
            options: [
                TweakOption("automatic", "Automatic"), TweakOption("scrolling", "When Scrolling"),
                TweakOption("always", "Always"),
            ],
            stock: "automatic",
            mechanism: .preferences([
                PreferenceBinding(.global, "AppleShowScrollBars", [
                    "automatic": .string("Automatic"), "scrolling": .string("WhenScrolling"), "always": .string("Always"),
                ])
            ])
        ),
        .toggle(
            "windows.restore", "Reopen windows",
            "Apps bring back the windows you had open.",
            in: .windows, "Behavior", .global, "NSQuitAlwaysKeepsWindows", stock: false, effect: .appRelaunch
        ),
    ]
}
