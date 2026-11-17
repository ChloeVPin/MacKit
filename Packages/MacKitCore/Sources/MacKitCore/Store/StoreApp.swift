import Foundation

/// An app that can be downloaded from its maker and installed.
///
/// The details come from Homebrew Cask, a public, community-reviewed list of
/// Mac apps and where their makers publish them.
public struct StoreApp: Identifiable, Hashable, Sendable, Codable {
    /// One app bundle inside the download, and the name it is installed as.
    public struct Bundle: Hashable, Sendable, Codable {
        /// Where the bundle sits in the download, such as `Foo.app`.
        public let source: String
        /// The name it gets in the Applications folder.
        public let installedName: String

        public init(source: String, installedName: String) {
            self.source = source
            self.installedName = installedName
        }

        /// Whether `source` and `installedName` stay safely inside their
        /// archive and destination folders as a `.app` bundle.
        public var isSafe: Bool {
            guard !source.isEmpty, !source.hasPrefix("/"), !source.contains("\0") else { return false }
            let components = source.split(separator: "/", omittingEmptySubsequences: false)
            guard !components.contains(".."), !components.contains(".") else { return false }
            return Self.isValidBundleName(installedName)
        }

        public static func isValidBundleName(_ name: String) -> Bool {
            name.count > 4
                && !name.hasPrefix(".")
                && !name.contains("/")
                && !name.contains("\0")
                && name.lowercased().hasSuffix(".app")
        }
    }

    /// Homebrew's name for the app, such as `visual-studio-code`.
    public let id: String
    public let name: String
    public let summary: String
    public let homepage: URL?
    public let version: String
    public let downloadURL: URL
    /// The SHA-256 the download must match. `nil` when the maker replaces
    /// the file in place, so no fixed checksum exists.
    public let checksum: String?
    public let bundles: [Bundle]
    /// The oldest major version of macOS the app runs on, if stated.
    public let minimumSystem: Int?
    /// Whether the app keeps itself up to date once installed.
    public let updatesItself: Bool
    /// Installs through Homebrew in the last 30 days: a measure of how
    /// popular the app is.
    public var installs: Int
    public var category: StoreCategory?

    public init(
        id: String, name: String, summary: String, homepage: URL?, version: String, downloadURL: URL,
        checksum: String?, bundles: [Bundle], minimumSystem: Int?, updatesItself: Bool,
        installs: Int = 0, category: StoreCategory? = nil
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.homepage = homepage
        self.version = version
        self.downloadURL = downloadURL
        self.checksum = checksum
        self.bundles = bundles
        self.minimumSystem = minimumSystem
        self.updatesItself = updatesItself
        self.installs = installs
        self.category = category
    }

    /// The version as people write it. Homebrew appends build details after
    /// a comma, as in `4.2.1,2031`.
    public var displayVersion: String {
        let raw = String(version.split(separator: ",").first ?? Substring(version))
        return raw.caseInsensitiveCompare("latest") == .orderedSame ? "Latest" : raw
    }

    /// The site the download comes from, such as `github.com`.
    public var downloadHost: String {
        downloadURL.host(percentEncoded: false)?.replacing(/^www\./, with: "") ?? downloadURL.absoluteString
    }
}

public enum StoreCategory: String, CaseIterable, Identifiable, Sendable, Codable {
    case browsers, productivity, developer, communication, media, design, utilities, security, ai, games

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .browsers: "Browsers"
        case .productivity: "Productivity"
        case .developer: "Developer Tools"
        case .communication: "Communication"
        case .media: "Music & Video"
        case .design: "Design & Photo"
        case .utilities: "Utilities"
        case .security: "Security & Privacy"
        case .ai: "AI"
        case .games: "Games"
        }
    }
}

/// Whether one version string is newer than another, comparing the numbers
/// in order: 2.10 is newer than 2.9.
public func isVersion(_ candidate: String, newerThan installed: String) -> Bool {
    func parts(_ text: String) -> [Int] {
        text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    }
    let (new, old) = (parts(candidate), parts(installed))
    guard !new.isEmpty, !old.isEmpty else { return false }
    for index in 0..<max(new.count, old.count) {
        let (a, b) = (index < new.count ? new[index] : 0, index < old.count ? old[index] : 0)
        if a != b { return a > b }
    }
    return false
}
