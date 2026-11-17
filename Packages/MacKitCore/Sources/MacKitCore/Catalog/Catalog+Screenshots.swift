import Foundation

extension Catalog {
    // MARK: Screenshots

    static func screenshots(home: URL) -> [Tweak] {
        func folder(_ name: String) -> PreferenceValue {
            .string(home.appending(path: name, directoryHint: .isDirectory).path(percentEncoded: false).trimmingSuffix("/"))
        }
        return [
            Tweak(
                id: "screenshot.format", title: "Format",
                summary: "PNG is sharpest. JPEG and HEIC make smaller files.",
                category: .screenshots, section: "Saving",
                options: [
                    TweakOption("png", "PNG"), TweakOption("jpg", "JPEG"), TweakOption("heic", "HEIC"),
                    TweakOption("pdf", "PDF"), TweakOption("tiff", "TIFF"),
                ],
                stock: "png",
                mechanism: .preferences([
                    PreferenceBinding(.app("com.apple.screencapture"), "type", [
                        "png": .string("png"), "jpg": .string("jpg"), "heic": .string("heic"),
                        "pdf": .string("pdf"), "tiff": .string("tiff"),
                    ])
                ]),
                effect: .restarts(.systemUIServer)
            ),
            Tweak(
                id: "screenshot.location", title: "Save to",
                summary: "The folder new screenshots land in.",
                category: .screenshots, section: "Saving",
                options: [
                    TweakOption("desktop", "Desktop"), TweakOption("downloads", "Downloads"),
                    TweakOption("pictures", "Pictures"),
                ],
                stock: "desktop",
                mechanism: .preferences([
                    PreferenceBinding(.app("com.apple.screencapture"), "location", [
                        "desktop": folder("Desktop"), "downloads": folder("Downloads"), "pictures": folder("Pictures"),
                    ])
                ]),
                effect: .restarts(.systemUIServer)
            ),
            .toggle(
                "screenshot.shadow", "Window shadow",
                "Include the soft shadow when capturing a single window.",
                in: .screenshots, "Appearance", .app("com.apple.screencapture"), "disable-shadow", stock: true,
                on: .bool(false), off: .bool(true), effect: .restarts(.systemUIServer)
            ),
            .toggle(
                "screenshot.thumbnail", "Floating thumbnail",
                "Show a preview in the corner after each capture.",
                in: .screenshots, "Appearance", .app("com.apple.screencapture"), "show-thumbnail", stock: true,
                effect: .restarts(.systemUIServer)
            ),
        ]
    }
}
