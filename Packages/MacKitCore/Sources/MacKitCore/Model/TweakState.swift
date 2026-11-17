import Foundation

/// What a tweak is currently set to on this Mac.
public enum TweakState: Hashable, Sendable {
    /// The system matches one of the tweak's options.
    case option(TweakOption.ID)
    /// The system holds a value MacKit doesn't offer, for example a Dock
    /// delay set by hand. The associated text is the raw value.
    case custom(String)
    /// The state couldn't be read.
    case unknown

    public var optionID: TweakOption.ID? {
        if case .option(let id) = self { id } else { nil }
    }
}

/// A raw record of what a tweak looked like before MacKit changed it, precise
/// enough to put it back exactly.
public enum Snapshot: Hashable, Sendable, Codable {
    /// The stored value of each key, in the order of the tweak's bindings.
    /// `nil` means the key was absent.
    case preferences([PreferenceSnapshot])
    case libraryHidden(Bool)
    /// The option a privileged setting was in. `nil` if it couldn't be read.
    case privileged(TweakOption.ID?)
}

public struct PreferenceSnapshot: Hashable, Sendable, Codable {
    public let domain: PreferenceDomain
    public let path: [String]
    public let key: String
    public let value: PreferenceValue?

    public init(domain: PreferenceDomain, path: [String] = [], key: String, value: PreferenceValue?) {
        self.domain = domain
        self.path = path
        self.key = key
        self.value = value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        domain = try container.decode(PreferenceDomain.self, forKey: .domain)
        path = try container.decodeIfPresent([String].self, forKey: .path) ?? []
        key = try container.decode(String.self, forKey: .key)
        value = try container.decodeIfPresent(PreferenceValue.self, forKey: .value)
    }
}
