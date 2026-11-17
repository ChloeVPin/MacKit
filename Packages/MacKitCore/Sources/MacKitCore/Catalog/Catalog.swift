import Foundation
import Synchronization

/// Every setting MacKit knows how to change.
///
/// Inclusion rules: the setting must be reversible, and its key must still
/// be read by current macOS (checked against the system binaries or a
/// recent source). A setting with a real downside carries a `caution`.
/// Keys that no longer do anything stay out.
public enum Catalog {
    /// - Parameter home: The user's home directory, used for settings whose
    ///   values are paths.
    public static func tweaks(home: URL) -> [Tweak] {
        let lists: [[Tweak]] = [
            finder, finderMore, desktop, dock, dockMore, missionControl, windows, windowsMore,
            appearanceMore, appearanceFromSystem, menuBarFromSystem, menuBarClock, sound, accessibility,
            keyboard, keyboardMore, trackpadAndMouse,
            screenshots(home: home), screenshotsMore, apps,
            power, sharing, continuity, security, securityMore, privacy, updates, startupAndLogin, screenSaver, region, textSettings,
        ]
        return arranged(lists.flatMap { $0 })
    }

    /// Orders settings by category, and within a category keeps each
    /// section's settings together, in the order the sections first appear.
    /// The lists above are written by topic, so one section can be fed from
    /// several of them.
    private static func arranged(_ tweaks: [Tweak]) -> [Tweak] {
        TweakCategory.allCases.flatMap { category -> [Tweak] in
            let members = tweaks.filter { $0.category == category }
            var sections: [String] = []
            for tweak in members where !sections.contains(tweak.section) { sections.append(tweak.section) }
            return sections.flatMap { section in members.filter { $0.section == section } }
        }
    }
}

extension Tweak {
    /// An on/off setting backed by a single boolean preference key.
    ///
    /// - Parameters:
    ///   - stock: Whether the setting is on in a fresh install of macOS.
    ///   - on: The value stored when the setting is on. Override for keys with
    ///     inverted meaning, such as `disable-shadow`.
    static func toggle(
        _ id: ID, _ title: String, _ summary: String,
        in category: TweakCategory, _ section: String,
        _ domain: PreferenceDomain, path: [String] = [], _ key: String,
        stock: Bool,
        on: PreferenceValue = .bool(true), off: PreferenceValue = .bool(false),
        effect: Effect = .immediate,
        caution: String? = nil,
        requiresBattery: Bool = false
    ) -> Tweak {
        Tweak(
            id: id, title: title, summary: summary, category: category, section: section,
            options: TweakOption.toggle,
            stock: stock ? "on" : "off",
            mechanism: .preferences([PreferenceBinding(domain, path: path, key, ["on": on, "off": off])]),
            effect: effect,
            caution: caution,
            requiresBattery: requiresBattery
        )
    }

    /// A setting with several named choices, backed by one preference key.
    ///
    /// - Parameter choices: Each option's identifier, label, and stored value,
    ///   in display order.
    static func choice(
        _ id: ID, _ title: String, _ summary: String,
        in category: TweakCategory, _ section: String,
        _ domain: PreferenceDomain, path: [String] = [], _ key: String,
        _ choices: [(id: TweakOption.ID, label: String, value: PreferenceValue)],
        stock: TweakOption.ID,
        removesWhenStock: Bool = false,
        effect: Effect = .immediate,
        caution: String? = nil
    ) -> Tweak {
        let mapped = Dictionary(uniqueKeysWithValues: choices.compactMap { choice in
            removesWhenStock && choice.id == stock ? nil : (choice.id, choice.value)
        })
        return Tweak(
            id: id, title: title, summary: summary, category: category, section: section,
            options: choices.map { TweakOption($0.id, $0.label) },
            stock: stock,
            mechanism: .preferences([
                PreferenceBinding(domain, path: path, key, mapped)
            ]),
            effect: effect,
            caution: caution
        )
    }
}

extension Tweak {
    /// A number chosen on a slider, stored in one preference key.
    ///
    /// - Parameter stock: The value macOS ships with. The key is usually
    ///   absent until the setting is changed, which reads as this value.
    static func slider(
        _ id: ID, _ title: String, _ summary: String,
        in category: TweakCategory, _ section: String,
        _ domain: PreferenceDomain, path: [String] = [], _ key: String,
        _ number: NumberInput, stock: Double,
        effect: Effect = .immediate,
        caution: String? = nil
    ) -> Tweak {
        let value: PreferenceValue = number.isInteger ? .int(Int(stock)) : .double(stock)
        return Tweak(
            id: id, title: title, summary: summary, category: category, section: section,
            options: [TweakOption("default", number.label(for: stock))],
            stock: "default",
            mechanism: .preferences([PreferenceBinding(domain, path: path, key, ["default": value])]),
            effect: effect, caution: caution,
            input: .number(number)
        )
    }

    /// A line of text stored in one preference key. An empty field removes
    /// the key, which is how macOS ships.
    static func text(
        _ id: ID, _ title: String, _ summary: String,
        in category: TweakCategory, _ section: String,
        _ domain: PreferenceDomain, _ key: String,
        _ text: TextInput,
        effect: Effect = .immediate,
        caution: String? = nil
    ) -> Tweak {
        Tweak(
            id: id, title: title, summary: summary, category: category, section: section,
            options: [TweakOption("default", text.emptyLabel)],
            stock: "default",
            mechanism: .preferences([PreferenceBinding(domain, key, [:])]),
            effect: effect, caution: caution,
            input: .text(text)
        )
    }
}

extension Catalog {
    /// Apps whose preferences macOS always keeps in a protected container.
    /// Reading or writing them needs Full Disk Access.
    public static let protectedDomains: Set<String> = [
        "com.apple.Safari", "com.apple.TextEdit", "com.apple.Preview", "com.apple.Photos", "com.apple.MobileSMS",
        "com.apple.archiveutility", "com.apple.iCal", "com.apple.universalaccess",
    ]

    /// Whether an app's preferences are behind macOS's app-data protection
    /// on this Mac.
    ///
    /// Which apps have a container varies between versions of macOS, so
    /// beyond the known list this checks for one. It matters: reading a
    /// protected app's settings without permission makes macOS stop and ask
    /// the user, and the read waits for their answer.
    public static func isProtected(_ domain: String) -> Bool {
        if protectedDomains.contains(domain) { return true }
        return containerChecks.withLock { known in
            if let answer = known[domain] { return answer }
            let container = NSHomeDirectory() + "/Library/Containers/" + domain
            let answer = domain.hasPrefix("com.apple.") && FileManager.default.fileExists(atPath: container)
            known[domain] = answer
            return answer
        }
    }

    private static let containerChecks = Mutex<[String: Bool]>([:])
}

extension Tweak {
    /// Whether macOS only lets an app with Full Disk Access change this.
    public var requiresFullDiskAccess: Bool {
        guard case .preferences(let bindings) = mechanism else { return false }
        return bindings.contains { binding in
            switch binding.domain {
            case .app(let identifier), .currentHost(let identifier): Catalog.isProtected(identifier)
            case .global, .currentHostGlobal, .system: false
            }
        }
    }
}

extension String {
    func trimmingSuffix(_ suffix: String) -> String {
        count > suffix.count && hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }
}
