import Foundation

/// Reads Homebrew's published list of apps.
///
/// The list covers far more than MacKit installs. This keeps the entries
/// that are a plain app in a disk image or archive, run on this Mac, and
/// haven't been retired. Installer packages, fonts, and command-line tools
/// are left out.
public enum CaskCatalog {
    public static let listURL = URL(string: "https://formulae.brew.sh/api/cask.json")!
    public static let popularityURL = URL(string: "https://formulae.brew.sh/api/analytics/cask-install/30d.json")!

    /// The Mac the catalog is being read for.
    public struct Platform: Sendable, Hashable {
        public let systemVersion: Int
        public let isAppleSilicon: Bool

        public init(systemVersion: Int, isAppleSilicon: Bool) {
            self.systemVersion = systemVersion
            self.isAppleSilicon = isAppleSilicon
        }

        public static var current: Platform {
            var isARM = false
            #if arch(arm64)
            isARM = true
            #endif
            return Platform(systemVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion, isAppleSilicon: isARM)
        }

        /// Homebrew's name for this system and chip, such as `arm64_tahoe`.
        var key: String? {
            let names = [27: "golden_gate", 26: "tahoe", 15: "sequoia", 14: "sonoma", 13: "ventura"]
            guard let name = names[systemVersion] else { return nil }
            return isAppleSilicon ? "arm64_" + name : name
        }
    }

    /// - Parameters:
    ///   - list: The contents of `cask.json`.
    ///   - popularity: The contents of the 30-day install report, if it
    ///     could be fetched.
    public static func apps(list: Data, popularity: Data?, platform: Platform = .current) throws -> [StoreApp] {
        let casks = try JSONDecoder().decode([Cask].self, from: list)
        let installs = popularity.flatMap { try? JSONDecoder().decode(Popularity.self, from: $0) }?.counts ?? [:]
        return casks.compactMap { cask in
            guard var app = cask.app(for: platform) else { return nil }
            app.installs = installs[app.id] ?? 0
            app.category = StoreCategory.of(app.id)
            return app
        }
    }

    private struct Popularity: Decodable {
        struct Item: Decodable {
            let cask: String
            let count: String
        }

        let items: [Item]

        var counts: [String: Int] {
            Dictionary(items.map { ($0.cask, Int($0.count.replacing(",", with: "")) ?? 0) }, uniquingKeysWith: max)
        }
    }

    private struct Cask: Decodable {
        struct Variation: Decodable {
            let url: String?
            let sha256: String?
            let version: String?
        }

        let token: String
        let name: [String]
        let desc: String?
        let homepage: String?
        let url: String
        let version: String
        let sha256: String?
        let artifacts: [[String: JSONValue]]
        let depends_on: [String: JSONValue]?
        let auto_updates: Bool?
        let deprecated: Bool?
        let disabled: Bool?
        let variations: [String: Variation]?
        let supported_platforms: [String]?

        func app(for platform: Platform) -> StoreApp? {
            guard deprecated != true, disabled != true else { return nil }
            if let supported = supported_platforms, let key = platform.key, !supported.contains(key) { return nil }

            // Anything that needs an installer package is beyond a copy into
            // Applications. Extra steps some apps list, such as linking a
            // command-line tool, are skipped: the app sets those up itself.
            let kinds = Set(artifacts.flatMap(\.keys))
            guard kinds.isDisjoint(with: ["pkg", "installer", "suite"]) else { return nil }

            let bundles = artifacts.compactMap { artifact -> StoreApp.Bundle? in
                guard case .array(let parts)? = artifact["app"], case .string(let source)? = parts.first else { return nil }
                // An entry may rename the bundle, as `{"target": "New.app"}`.
                var target = (source as NSString).lastPathComponent
                for case .object(let options) in parts.dropFirst() {
                    if case .string(let path)? = options["target"] { target = (path as NSString).lastPathComponent }
                }
                return StoreApp.Bundle(source: source, installedName: target)
            }
            guard !bundles.isEmpty, bundles.allSatisfy(\.isSafe) else { return nil }

            let variation = platform.key.flatMap { variations?[$0] }
            guard let download = URL(string: variation?.url ?? url), download.scheme == "https" else { return nil }
            let hash = variation?.sha256 ?? sha256
            let checksum: String?
            if hash == nil || hash == "no_check" {
                checksum = nil
            } else if let hash, hash.count == 64, hash.unicodeScalars.allSatisfy({
                ("0"..."9").contains($0) || ("a"..."f").contains($0) || ("A"..."F").contains($0)
            }) {
                checksum = hash.lowercased()
            } else {
                return nil
            }

            var minimum: Int?
            if case .object(let systems)? = depends_on?["macos"], case .array(let versions)? = systems[">="],
               case .string(let text)? = versions.first {
                minimum = Int(text.split(separator: ".").first ?? "")
            }
            if let minimum, minimum > platform.systemVersion { return nil }

            return StoreApp(
                id: token,
                name: name.first ?? token,
                summary: desc ?? "",
                homepage: homepage.flatMap(URL.init(string:)),
                version: variation?.version ?? version,
                downloadURL: download,
                checksum: checksum,
                bundles: bundles,
                minimumSystem: minimum,
                updatesItself: auto_updates ?? false
            )
        }
    }
}

/// Just enough JSON to read the loosely shaped parts of a cask.
enum JSONValue: Decodable {
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
    case other

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .string(text)
        } else if let items = try? container.decode([JSONValue].self) {
            self = .array(items)
        } else if let fields = try? container.decode([String: JSONValue].self) {
            self = .object(fields)
        } else {
            self = .other
        }
    }
}
