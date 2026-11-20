import Foundation
import ImageIO
import Synchronization

/// A picture found for an app, and where it came from.
public struct FoundIcon: Sendable {
    public enum Source: String, Sendable, CaseIterable {
        /// A community collection of real Mac app icons.
        case collection
        /// Apple's App Store listing for an app of the same name.
        case appStore
        /// The icon the maker's own site declares.
        case website
        /// The maker's GitHub picture.
        case github
        /// The site's favicon, from a favicon service.
        case favicon
    }

    public let data: Data
    public let source: Source
    /// The longer side, in pixels.
    public let pixels: Int
}

/// Finds a picture for an app that isn't installed yet.
///
/// Homebrew's list has no icons, so this looks in several places, best
/// first, and takes the first good one. Small favicons are a last resort:
/// they are only used when nothing sharper turns up.
public enum IconFinder {
    /// Below this, a picture is too small to show at icon size.
    public static let sharpEnough = 96
    static let smallestUsable = 32
    /// How long a "no icon found" marker is trusted before trying again.
    public static let negativeCacheLifetime: TimeInterval = 24 * 3600

    public enum Lookup: Sendable {
        case found(FoundIcon)
        /// Servers answered, and none of the candidate locations had a usable icon.
        case noneFound
        /// Every network request failed before receiving an HTTP response (for example, offline).
        case unreachable
    }

    public typealias Fetcher = @Sendable (URL) async -> (data: Data, statusCode: Int)?

    @concurrent
    public static func find(for app: StoreApp) async -> FoundIcon? {
        if case .found(let icon) = await lookup(for: app) { return icon }
        return nil
    }

    @concurrent
    public static func lookup(for app: StoreApp, fetch: @escaping Fetcher = liveFetch) async -> Lookup {
        let tracker = ReachabilityTracker(fetch: fetch)
        var fallback: FoundIcon?
        for candidate in candidates(for: app, fetch: { await tracker.data(from: $0) }) {
            guard let icon = await candidate() else { continue }
            if icon.pixels >= sharpEnough { return .found(icon) }
            if icon.pixels >= smallestUsable, icon.pixels > (fallback?.pixels ?? 0) { fallback = icon }
        }
        if let fallback { return .found(fallback) }
        return tracker.didReceiveHTTPResponse ? .noneFound : .unreachable
    }

    public enum CachedIconData: Sendable, Equatable {
        case icon(Data)
        case missing
    }

    public static func readCache(for appID: String, in folder: URL, now: Date = .now) -> CachedIconData? {
        let file = cacheFileURL(for: appID, in: folder)
        if let data = try? Data(contentsOf: file), !data.isEmpty { return .icon(data) }
        let marker = file.appendingPathExtension("none")
        guard FileManager.default.fileExists(atPath: marker.path(percentEncoded: false)) else { return nil }
        if let modified = (try? marker.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate),
           now.timeIntervalSince(modified) < negativeCacheLifetime {
            return .missing
        }
        try? FileManager.default.removeItem(at: marker)
        return nil
    }

    public static func writeCache(_ lookup: Lookup, for appID: String, in folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = cacheFileURL(for: appID, in: folder)
        let marker = file.appendingPathExtension("none")
        switch lookup {
        case .found(let found):
            try? FileManager.default.removeItem(at: marker)
            try? found.data.write(to: file, options: .atomic)
        case .noneFound:
            try? Data().write(to: marker, options: .atomic)
        case .unreachable:
            // Never record an offline failure as a missing icon.
            break
        }
    }

    private static func cacheFileURL(for appID: String, in folder: URL) -> URL {
        folder.appending(path: appID.replacing("/", with: "_") + ".icon")
    }

    private final class ReachabilityTracker: Sendable {
        private let fetch: Fetcher
        private let responded = Synchronization.Mutex(false)

        init(fetch: @escaping Fetcher) { self.fetch = fetch }

        var didReceiveHTTPResponse: Bool { responded.withLock { $0 } }

        func data(from url: URL) async -> Data? {
            guard let response = await fetch(url) else { return nil }
            responded.withLock { $0 = true }
            guard response.statusCode == 200, !response.data.isEmpty else { return nil }
            return response.data
        }
    }

    private typealias Candidate = @Sendable () async -> FoundIcon?
    private typealias DataLoader = @Sendable (URL) async -> Data?

    private static func candidates(for app: StoreApp, fetch: @escaping DataLoader) -> [Candidate] {
        var list: [Candidate] = []
        func image(_ address: String, _ source: FoundIcon.Source) {
            guard let url = URL(string: address) else { return }
            list.append { await icon(at: url, source, fetch: fetch) }
        }

        image("https://github.com/App-Fair/appcasks/releases/download/cask-\(app.id)/AppIcon.png", .collection)
        list.append { await appStoreIcon(named: app.name, fetch: fetch) }

        let homepage = app.homepage
        let host = homepage?.host(percentEncoded: false)
        let onGitHub = isGitHub(host)

        if let homepage, let host, !onGitHub {
            list.append { await declaredIcon(on: homepage, fetch: fetch) }
            image("https://\(host)/apple-touch-icon.png", .website)
        }
        // A project's page on GitHub carries GitHub's own logo. Its owner's
        // picture says more about the app.
        for url in [homepage, app.downloadURL].compactMap(\.self) where isGitHub(url.host(percentEncoded: false)) {
            if let owner = url.pathComponents.dropFirst().first {
                image("https://github.com/\(owner).png?size=256", .github)
                break
            }
        }
        if let host, !onGitHub {
            image("https://\(host)/favicon.ico", .favicon)
            image("https://www.google.com/s2/favicons?domain=\(host)&sz=256", .favicon)
            image("https://icons.duckduckgo.com/ip3/\(host).ico", .favicon)
        }
        return list
    }

    /// Whether `host` is GitHub itself, not merely a name ending in the
    /// same letters, such as `notgithub.com`.
    private static func isGitHub(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "github.com" || host.hasSuffix(".github.com")
    }

    // MARK: Sources

    private static func icon(at url: URL, _ source: FoundIcon.Source, fetch: @escaping DataLoader) async -> FoundIcon? {
        guard let data = await fetch(url), let pixels = pixelSize(of: data) else { return nil }
        return FoundIcon(data: data, source: source, pixels: pixels)
    }

    /// The App Store's artwork, but only for a listing whose name is exactly
    /// the app's. A near match could be someone else's app.
    private static func appStoreIcon(named name: String, fetch: @escaping DataLoader) async -> FoundIcon? {
        struct Results: Decodable {
            struct Listing: Decodable {
                let trackName: String
                let artworkUrl512: String?
            }

            let results: [Listing]
        }
        func normalized(_ text: String) -> String {
            text.lowercased().filter { $0.isLetter || $0.isNumber }
        }

        for kind in ["macSoftware", "software"] {
            var components = URLComponents(string: "https://itunes.apple.com/search")!
            components.queryItems = [
                .init(name: "term", value: name), .init(name: "entity", value: kind),
                .init(name: "limit", value: "5"), .init(name: "country", value: "us"),
            ]
            guard let url = components.url, let data = await fetch(url),
                  let found = try? JSONDecoder().decode(Results.self, from: data) else { continue }
            // Listings often add a tagline: "Slack for Desktop", "Notion: Notes, Docs".
            let wanted = normalized(name)
            let match = found.results.first { listing in
                let title = listing.trackName.split(whereSeparator: { ":-–—|".contains($0) }).first.map(String.init) ?? listing.trackName
                return normalized(title) == wanted
            }
            if let address = match?.artworkUrl512, let artwork = URL(string: address), let icon = await icon(at: artwork, .appStore, fetch: fetch) {
                return icon
            }
        }
        return nil
    }

    /// The icons a web page names in its `<head>`, largest first.
    private static func declaredIcon(on page: URL, fetch: @escaping DataLoader) async -> FoundIcon? {
        guard let html = await fetch(page).map({ String(decoding: $0.prefix(400_000), as: UTF8.self) }) else { return nil }
        var found: [(url: URL, size: Int)] = []
        for match in html.matches(of: /<link\b[^>]*>/.ignoresCase()) {
            let tag = String(match.output)
            guard let rel = tag.firstMatch(of: /\brel=["']?([^"'>]+)/.ignoresCase())?.output.1.lowercased(),
                  rel.contains("icon"), !rel.contains("mask"),
                  let href = tag.firstMatch(of: /\bhref=["']([^"']+)["']/.ignoresCase())?.output.1,
                  let url = URL(string: String(href).replacing("&amp;", with: "&"), relativeTo: page)?.absoluteURL,
                  url.scheme == "https", !url.path().lowercased().hasSuffix(".svg") else { continue }
            let declared = tag.firstMatch(of: /\bsizes=["']?(\d+)x/.ignoresCase()).flatMap { Int($0.output.1) }
            // A touch icon with no stated size is 180 pixels by convention.
            found.append((url, declared ?? (rel.contains("apple-touch") ? 180 : 16)))
        }
        for candidate in found.sorted(by: { $0.size > $1.size }).prefix(3) {
            if let icon = await icon(at: candidate.url, .website, fetch: fetch), icon.pixels >= smallestUsable { return icon }
        }
        return nil
    }

    // MARK: Fetching

    public static func liveFetch(_ url: URL) async -> (data: Data, statusCode: Int)? {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(
            "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return nil }
        return (data, http.statusCode)
    }

    /// The longer side of an image, or `nil` if the data isn't one. An
    /// `.ico` file holds several sizes, so the largest counts.
    public static func pixelSize(of data: Data) -> Int? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let sizes = (0..<CGImageSourceGetCount(source)).compactMap { index -> Int? in
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
            return max(width, height)
        }
        return sizes.max()
    }
}
