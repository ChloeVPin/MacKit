import Foundation

/// A curated group of settings that go well together.
///
/// Choosing a quick setup doesn't apply anything. It selects its settings,
/// and they go through the same review as any other change.
public struct QuickSetup: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    /// The category the setup mostly belongs to, used for its icon.
    public let category: TweakCategory
    /// The option each setting is moved to, in display order.
    public let selections: [Selection]

    public struct Selection: Hashable, Sendable {
        public let tweakID: Tweak.ID
        public let option: TweakOption.ID

        public init(_ tweakID: Tweak.ID, _ option: TweakOption.ID) {
            self.tweakID = tweakID
            self.option = option
        }
    }

    public static let all: [QuickSetup] = [
        QuickSetup(
            id: "developer", title: "Developer",
            summary: "See every file, type code without corrections, and move faster with the keyboard.",
            category: .keyboard,
            selections: [
                .init("finder.hidden-files", "on"),
                .init("finder.extensions", "on"),
                .init("finder.path-bar", "on"),
                .init("keyboard.press-and-hold", "off"),
                .init("keyboard.repeat-rate", "fast"),
                .init("keyboard.repeat-delay", "short"),
                .init("text.smart-quotes", "off"),
                .init("text.smart-dashes", "off"),
                .init("text.autocorrect", "off"),
            ]
        ),
        QuickSetup(
            id: "calm-dock", title: "Calm Dock",
            summary: "A Dock that stays out of the way and keeps your Spaces where you put them.",
            category: .dock,
            selections: [
                .init("dock.autohide", "on"),
                .init("dock.reveal-speed", "fast"),
                .init("dock.recents", "off"),
                .init("dock.minimize-effect", "scale"),
                .init("dock.minimize-to-app", "on"),
                .init("dock.rearrange-spaces", "off"),
            ]
        ),
        QuickSetup(
            id: "power-finder", title: "Power Finder",
            summary: "More information in every window, and searches that start where you are.",
            category: .finder,
            selections: [
                .init("finder.extensions", "on"),
                .init("finder.path-bar", "on"),
                .init("finder.status-bar", "on"),
                .init("finder.folders-first", "on"),
                .init("finder.search-scope", "folder"),
                .init("windows.save-expanded", "on"),
            ]
        ),
        QuickSetup(
            id: "clean-captures", title: "Clean Captures",
            summary: "Screenshots without shadows, saved out of sight in your Pictures folder.",
            category: .screenshots,
            selections: [
                .init("screenshot.location", "pictures"),
                .init("screenshot.shadow", "off"),
                .init("screenshot.thumbnail", "off"),
            ]
        ),
    ]
}
