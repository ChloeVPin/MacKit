import Foundation

/// A value stored in the macOS preferences system (`defaults`).
///
/// Only the scalar types MacKit writes are modeled. Anything else a key might
/// hold (arrays, dictionaries, data) is read as `nil` and reported as a custom
/// state rather than guessed at.
public enum PreferenceValue: Hashable, Sendable, Codable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)

    /// Whether two values mean the same thing to the system.
    ///
    /// Preferences are loosely typed on disk: `defaults write -int 1` and
    /// `-bool true` are read back identically by the apps that consume them,
    /// and a float key may be stored as an integer.
    public func matches(_ other: PreferenceValue) -> Bool {
        switch (self, other) {
        case let (.string(a), .string(b)): a == b
        case (.string, _), (_, .string): false
        default: numericValue == other.numericValue
        }
    }

    private var numericValue: Double? {
        switch self {
        case .bool(let value): value ? 1 : 0
        case .int(let value): Double(value)
        case .double(let value): value
        case .string: nil
        }
    }

    /// The value as it would be typed after `defaults write <domain> <key>`.
    public var defaultsArguments: [String] {
        switch self {
        case .bool(let value): ["-bool", value ? "true" : "false"]
        case .int(let value): ["-int", String(value)]
        case .double(let value): ["-float", Self.format(value)]
        case .string(let value): ["-string", value]
        }
    }

    /// A short, human-readable rendering for showing a raw value in the UI.
    public var displayText: String {
        switch self {
        case .bool(let value): value ? "true" : "false"
        case .int(let value): String(value)
        case .double(let value): Self.format(value)
        case .string(let value): value
        }
    }

    private static func format(_ value: Double) -> String {
        // `Int(exactly:)` is nil for infinity and values past `Int`'s range,
        // which a hand-edited preference can hold; `Int(_:)` would crash.
        Int(exactly: value).map(String.init) ?? String(value)
    }
}

/// Where a preference key lives.
public enum PreferenceDomain: Hashable, Sendable, Codable {
    /// `NSGlobalDomain`: preferences every app reads.
    case global
    /// A specific bundle identifier, for example `com.apple.finder`.
    case app(String)
    /// `NSGlobalDomain` for this Mac only (`defaults -currentHost`).
    case currentHostGlobal
    /// A bundle identifier's preferences for this Mac only
    /// (`defaults -currentHost`). They live in `~/Library/Preferences/ByHost`.
    case currentHost(String)
    /// A preference file shared by every user, named by its absolute path
    /// without the `.plist` ending, for example
    /// `/Library/Preferences/com.apple.loginwindow`. Writing one needs root.
    case system(String)

    /// The domain as it is named on the `defaults` command line.
    public var commandLineName: String {
        switch self {
        case .global, .currentHostGlobal: "NSGlobalDomain"
        case .app(let identifier), .currentHost(let identifier): identifier
        case .system(let path): path
        }
    }

    public var isCurrentHost: Bool {
        switch self {
        case .currentHostGlobal, .currentHost: true
        case .global, .app, .system: false
        }
    }

    /// Whether writing to the domain needs an administrator.
    public var requiresAdministrator: Bool {
        if case .system = self { true } else { false }
    }

    /// Whether `defaults` writes this domain directly as a plist file rather
    /// than through `cfprefsd`, leaving `0600` root-only permissions unless
    /// restored afterward.
    public var isDirectSystemFile: Bool {
        guard case .system(let path) = self else { return false }
        let prefix = "/Library/Preferences/"
        return !(path.hasPrefix(prefix) && !path.dropFirst(prefix.count).contains("/"))
    }

    /// The words that go between `defaults` and the key: the verb, any
    /// `-currentHost` flag, and the domain.
    func defaultsArguments(_ verb: String) -> [String] {
        (isCurrentHost ? ["-currentHost"] : []) + [verb, commandLineName]
    }
}
