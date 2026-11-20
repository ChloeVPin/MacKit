import AppKit
import ImageIO
import MacKitCore
import Observation
import SwiftUI

/// Everything the app store needs from the outside world. The real one
/// talks to the network and the Applications folder; the sample one
/// pretends, so screens can be checked without downloading anything.
nonisolated protocol StoreBackend: Sendable {
    /// The apps on offer. `cachedOnly` returns what was saved last time, or
    /// nothing, without touching the network.
    func apps(cachedOnly: Bool) async throws -> [StoreApp]
    func installedVersion(of app: StoreApp) -> String?
    func install(_ app: StoreApp, onStage: @escaping @Sendable (InstallStage) -> Void) async throws(InstallError)
    func uninstall(_ app: StoreApp) throws(InstallError)
    func installedURL(of app: StoreApp) -> URL?
    func icon(for app: StoreApp) async -> StoreIcon?
}

// MARK: The real thing

nonisolated struct LiveStoreBackend: StoreBackend {
    private let installer = AppInstaller()
    private let icons = IconLoader()

    private var folder: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appending(path: "dev.mackit.MacKit/Store", directoryHint: .isDirectory)
    }

    @concurrent
    func apps(cachedOnly: Bool) async throws -> [StoreApp] {
        let saved = folder.appending(path: "apps.json")
        let age = (try? saved.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            .map { Date.now.timeIntervalSince($0) }
        let cached = (try? Data(contentsOf: saved)).flatMap { try? JSONDecoder().decode([StoreApp].self, from: $0) }

        // The list changes a few times a day at most. A copy from the last
        // half day is fresh enough.
        if let cached, cachedOnly || (age ?? .infinity) < 12 * 3600 { return cached }
        if cachedOnly { return [] }

        do {
            let (list, _) = try await URLSession.shared.data(from: CaskCatalog.listURL)
            let popularity = try? await URLSession.shared.data(from: CaskCatalog.popularityURL).0
            let apps = try CaskCatalog.apps(list: list, popularity: popularity)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? JSONEncoder().encode(apps).write(to: saved, options: .atomic)
            return apps
        } catch {
            // Offline: an old list is better than none.
            if let cached { return cached }
            throw error
        }
    }

    func installedVersion(of app: StoreApp) -> String? { installer.installedVersion(of: app) }
    func installedURL(of app: StoreApp) -> URL? { installer.installedURL(of: app) }

    func install(_ app: StoreApp, onStage: @escaping @Sendable (InstallStage) -> Void) async throws(InstallError) {
        try await installer.install(app, onStage: onStage)
    }

    func uninstall(_ app: StoreApp) throws(InstallError) { try installer.uninstall(app) }

    func icon(for app: StoreApp) async -> StoreIcon? {
        if let url = installer.installedURL(of: app) {
            let image = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
            image.size = NSSize(width: 96, height: 96)
            return StoreIcon(image: image, shape: .finished, cost: 96 * 96 * 4)
        }
        return await icons.icon(for: app, cache: folder.appending(path: "Icons", directoryHint: .isDirectory))
    }
}

/// An app's picture, and how it should be framed.
struct StoreIcon: @unchecked Sendable {
    enum Shape: Sendable {
        /// A finished Mac icon with its own shape and transparency.
        case finished
        /// A square picture that fills its frame, such as an App Store
        /// listing or a site's touch icon. Shown with rounded corners.
        case square
        /// A small favicon. Shown at a modest size on a plain tile, so it
        /// stays sharp.
        case small
    }

    let image: NSImage
    let shape: Shape
    var cost: Int = 64 * 1024
}

private final class CachedIconBox: NSObject {
    let icon: StoreIcon
    init(_ icon: StoreIcon) { self.icon = icon }
}

/// Loads and caches icons on disk, bounding concurrent network lookups so
/// scrolling a long list stays calm.
actor IconLoader {
    private static let maxConcurrent = 8
    /// Largest size an icon is drawn at (96pt at 2x).
    private static let maxPixelSize = 192

    private var missing: Set<String> = []
    private var inFlight: [String: Task<StoreIcon?, Never>] = [:]
    private var activeCount = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func icon(for app: StoreApp, cache: URL) async -> StoreIcon? {
        if missing.contains(app.id) { return nil }
        if let running = inFlight[app.id] { return await running.value }
        guard !Task.isCancelled else { return nil }

        let task = Task { () -> StoreIcon? in
            if let cached = await Self.readDiskCache(app, cache: cache) {
                return cached.icon
            }
            await acquireSlot()
            defer { releaseSlot() }
            guard !Task.isCancelled else { return nil }
            return await Self.fetchAndWrite(app, cache: cache)
        }
        inFlight[app.id] = task
        let icon = await task.value
        inFlight[app.id] = nil
        if icon == nil, !Task.isCancelled, IconFinder.readCache(for: app.id, in: cache) == .missing {
            missing.insert(app.id)
        }
        return icon
    }

    func resetMissing() {
        missing.removeAll()
    }

    private func acquireSlot() async {
        if activeCount < Self.maxConcurrent {
            activeCount += 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func releaseSlot() {
        if !waiters.isEmpty {
            let next = waiters.removeFirst()
            next.resume()
        } else {
            activeCount = max(0, activeCount - 1)
        }
    }

    @concurrent
    private static func readDiskCache(_ app: StoreApp, cache: URL) async -> (icon: StoreIcon?, hit: Bool)? {
        switch IconFinder.readCache(for: app.id, in: cache) {
        case .icon(let data):
            if let icon = framed(data) { return (icon, true) }
            return nil
        case .missing:
            return (nil, true)
        case nil:
            return nil
        }
    }

    @concurrent
    private static func fetchAndWrite(_ app: StoreApp, cache: URL) async -> StoreIcon? {
        let lookup = await IconFinder.lookup(for: app)
        switch lookup {
        case .found(let found):
            guard let icon = framed(found.data) else {
                if !Task.isCancelled { IconFinder.writeCache(.noneFound, for: app.id, in: cache) }
                return nil
            }
            IconFinder.writeCache(lookup, for: app.id, in: cache)
            return icon
        case .noneFound, .unreachable:
            if !Task.isCancelled { IconFinder.writeCache(lookup, for: app.id, in: cache) }
            return nil
        }
    }

    /// Downsamples the image to display size and decides how it should be
    /// framed from its size and whether its corners are see-through.
    nonisolated private static func framed(_ data: Data) -> StoreIcon? {
        guard let pixels = IconFinder.pixelSize(of: data),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(pixels, maxPixelSize),
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        let cost = max(cgImage.bytesPerRow * cgImage.height, 4096)

        if pixels < IconFinder.sharpEnough {
            return StoreIcon(image: image, shape: .small, cost: cost)
        }
        // A finished icon leaves its corners empty. A square picture fills them.
        guard bitmap.hasAlpha, let corner = bitmap.colorAt(x: 1, y: 1) else {
            return StoreIcon(image: image, shape: .square, cost: cost)
        }
        return StoreIcon(image: image, shape: corner.alphaComponent < 0.5 ? .finished : .square, cost: cost)
    }
}

// MARK: The model

/// What an app is doing right now, if anything.
enum StoreActivity: Equatable {
    case downloading(Double?)
    case verifying
    case installing
    case failed(String)
}

@Observable
final class StoreModel {
    enum Phase: Equatable {
        case loading
        case ready
        case failed(String)
    }

    enum Sort: String, CaseIterable, Identifiable {
        case popular = "Most Popular"
        case name = "Name"
        var id: String { rawValue }
    }

    enum CachedIcon {
        case unknown
        case found(StoreIcon)
        case missing
    }

    private let backend: any StoreBackend

    private(set) var phase: Phase = .loading
    private(set) var apps: [StoreApp] = []
    /// Installed version of each app found in Applications.
    private(set) var installed: [StoreApp.ID: String] = [:]
    private(set) var activity: [StoreApp.ID: StoreActivity] = [:]
    /// Incremented when an app is installed or removed so its icon reloads.
    private(set) var iconRevisions: [StoreApp.ID: Int] = [:]

    var category: StoreCategory? {
        didSet { if category != nil { showingPopularAll = false } }
    }
    var showingPopularAll = false
    var sort: Sort = .popular
    /// The app whose own page is showing.
    var openAppID: StoreApp.ID?

    @ObservationIgnored private let iconCache: NSCache<NSString, CachedIconBox> = {
        let cache = NSCache<NSString, CachedIconBox>()
        cache.countLimit = 256
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()
    @ObservationIgnored private var iconless: Set<StoreApp.ID> = []
    @ObservationIgnored private var tasks: [StoreApp.ID: Task<Void, Never>] = [:]
    @ObservationIgnored private var didLoad = false

    init(backend: any StoreBackend) {
        self.backend = backend
    }

    // MARK: Loading

    /// Loads the list the first time a store screen appears. A saved copy
    /// shows at once while a fresh one is fetched.
    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        if let saved = try? await backend.apps(cachedOnly: true), !saved.isEmpty { await show(saved) }
        await reload()
    }

    func reload() async {
        if phase == .ready { iconless.removeAll() }
        if apps.isEmpty { phase = .loading }
        do {
            await show(try await backend.apps(cachedOnly: false))
        } catch {
            if apps.isEmpty { phase = .failed("MacKit couldn't reach the app list. Check your internet connection.") }
        }
    }

    /// Puts a list on screen. The first time, the page stays on its spinner
    /// until the icons for the front page are in, so it appears all at once.
    private func show(_ list: [StoreApp]) async {
        apps = list.sorted { $0.installs > $1.installs }
        refreshInstalled()
        if phase != .ready {
            await loadIcons(for: frontApps, waitingUpTo: .seconds(6))
        }
        phase = .ready
    }

    /// The apps the front page opens with: the most popular, then the top of
    /// each category.
    private var frontApps: [StoreApp] {
        Array(apps.prefix(Self.popularCount)) + StoreCategory.allCases.flatMap { shelfApps(for: $0) }
    }

    /// Up to `shelfCount` apps for a category on the front page, preferring
    /// apps not already shown in `Popular Right Now`.
    func shelfApps(for category: StoreCategory) -> [StoreApp] {
        let all = apps(in: category)
        let popularIDs = Set(apps.prefix(Self.popularCount).map(\.id))
        let distinct = all.filter { !popularIDs.contains($0.id) }
        if distinct.count >= Self.shelfCount {
            return Array(distinct.prefix(Self.shelfCount))
        }
        return Array((distinct + all.filter { popularIDs.contains($0.id) }).prefix(Self.shelfCount))
    }

    static let popularCount = 8
    static let popularExpandedCount = 100
    static let shelfCount = 4

    /// Fetches icons together and returns when they are all in, or when the
    /// time is up. Stragglers keep loading and appear when they arrive.
    private func loadIcons(for apps: [StoreApp], waitingUpTo limit: Duration) async {
        let wanted = apps.filter { if case .unknown = cachedIcon(for: $0) { true } else { false } }
        guard !wanted.isEmpty else { return }
        let work = Task {
            await withTaskGroup(of: Void.self) { group in
                for app in wanted {
                    group.addTask { _ = await self.loadIcon(for: app) }
                }
            }
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var isDone = false
            let finish = {
                guard !isDone else { return }
                isDone = true
                continuation.resume()
            }
            Task { await work.value; finish() }
            Task { try? await Task.sleep(for: limit); finish() }
        }
    }

    private func record(_ icon: StoreIcon?, for id: StoreApp.ID) {
        if let icon {
            iconCache.setObject(CachedIconBox(icon), forKey: id as NSString, cost: icon.cost)
            iconless.remove(id)
        } else {
            iconless.insert(id)
        }
    }

    private func invalidateIcon(for id: StoreApp.ID) {
        iconCache.removeObject(forKey: id as NSString)
        iconless.remove(id)
        iconRevisions[id, default: 0] += 1
    }

    func refreshInstalled() {
        installed = Dictionary(uniqueKeysWithValues: apps.compactMap { app in
            backend.installedVersion(of: app).map { (app.id, $0) }
        })
    }

    // MARK: Reading

    func app(_ id: StoreApp.ID) -> StoreApp? { apps.first { $0.id == id } }

    func isInstalled(_ app: StoreApp) -> Bool { installed[app.id] != nil }

    /// Whether the app is downloading or installing right now.
    func isBusy(_ app: StoreApp) -> Bool {
        switch activity[app.id] {
        case nil, .failed: false
        default: true
        }
    }

    func hasUpdate(_ app: StoreApp) -> Bool {
        installed[app.id].map { isVersion(app.displayVersion, newerThan: $0) } ?? false
    }

    var installedApps: [StoreApp] {
        apps.filter(isInstalled).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var updateCount: Int { apps.count { hasUpdate($0) } }

    /// Apps in a category, in the chosen order.
    func apps(in category: StoreCategory?) -> [StoreApp] {
        let members = category.map { wanted in apps.filter { $0.category == wanted } } ?? apps
        switch sort {
        case .popular: return members
        case .name: return members.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    /// Apps matching what was typed: names first, then descriptions, each
    /// most popular first.
    func search(_ query: String) -> [StoreApp] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        let byName = apps.filter { $0.name.localizedStandardContains(query) || $0.id.localizedStandardContains(query) }
        let names = Set(byName.map(\.id))
        let byWords = apps.filter { !names.contains($0.id) && $0.summary.localizedStandardContains(query) }
        let starts = byName.filter { $0.name.lowercased().hasPrefix(query.lowercased()) }
        let startIDs = Set(starts.map(\.id))
        return starts + byName.filter { !startIDs.contains($0.id) } + byWords
    }

    // MARK: Icons

    func cachedIcon(for app: StoreApp) -> CachedIcon {
        if let box = iconCache.object(forKey: app.id as NSString) { return .found(box.icon) }
        if iconless.contains(app.id) { return .missing }
        return .unknown
    }

    func loadIcon(for app: StoreApp) async -> StoreIcon? {
        switch cachedIcon(for: app) {
        case .found(let icon): return icon
        case .missing: return nil
        case .unknown:
            let icon = await backend.icon(for: app)
            if icon != nil || !Task.isCancelled { record(icon, for: app.id) }
            return icon
        }
    }

    // MARK: Acting

    func install(_ app: StoreApp) {
        guard tasks[app.id] == nil else { return }
        activity[app.id] = .downloading(0)
        tasks[app.id] = Task {
            do throws(InstallError) {
                try await backend.install(app) { stage in
                    Task { @MainActor in
                        // A late progress report must not overwrite the end.
                        guard self.tasks[app.id] != nil else { return }
                        switch stage {
                        case .downloading(let fraction): self.activity[app.id] = .downloading(fraction)
                        case .verifying: self.activity[app.id] = .verifying
                        case .installing: self.activity[app.id] = .installing
                        }
                    }
                }
                tasks[app.id] = nil
                activity[app.id] = nil
                refreshInstalled()
                // The real icon replaces whatever stood in for it.
                invalidateIcon(for: app.id)
            } catch {
                tasks[app.id] = nil
                activity[app.id] = error == .cancelled ? nil : .failed(error.explanation)
            }
        }
    }

    func cancel(_ app: StoreApp) {
        tasks[app.id]?.cancel()
    }

    func dismissFailure(_ app: StoreApp) {
        if case .failed = activity[app.id] { activity[app.id] = nil }
    }

    /// Moves an installed app to the Trash. A failure is thrown rather than
    /// kept as the app's activity, because a failed install offers Retry,
    /// and retrying here would install the app again.
    func uninstall(_ app: StoreApp) throws(InstallError) {
        try backend.uninstall(app)
        refreshInstalled()
        invalidateIcon(for: app.id)
    }

    func open(_ app: StoreApp) {
        if let url = backend.installedURL(of: app) { NSWorkspace.shared.open(url) }
    }

    func showInFinder(_ app: StoreApp) {
        if let url = backend.installedURL(of: app) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }
}

// MARK: The pretend one

/// A small shelf of well-known apps that installs nothing and never touches
/// the network.
nonisolated final class SampleStoreBackend: StoreBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var versions: [String: String] = ["rectangle": "0.80", "iina": "1.4.1", "visual-studio-code": "1.146.0"]
    private let fails: Bool

    init(fails: Bool = false) {
        self.fails = fails
    }

    func apps(cachedOnly: Bool) async throws -> [StoreApp] {
        let shelf: [(String, String, String, StoreCategory, Int, String, Bool)] = [
            ("visual-studio-code", "Visual Studio Code", "Open-source code editor", .developer, 310_000, "1.146.0", true),
            ("google-chrome", "Google Chrome", "Web browser", .browsers, 220_000, "142.0", false),
            ("obsidian", "Obsidian", "Knowledge base that works on top of a local folder of plain text Markdown files", .productivity, 180_000, "1.9.4", true),
            ("ghostty", "Ghostty", "Terminal emulator that uses platform-native UI and GPU acceleration", .developer, 170_000, "1.2.0", true),
            ("firefox", "Mozilla Firefox", "Web browser", .browsers, 150_000, "145.0", true),
            ("rectangle", "Rectangle", "Move and resize windows using keyboard shortcuts or snap areas", .utilities, 140_000, "2.0.4", true),
            ("raycast", "Raycast", "Control your tools with a few keystrokes", .productivity, 130_000, "1.103", true),
            ("spotify", "Spotify", "Music streaming service", .media, 120_000, "1.2.74", false),
            ("discord", "Discord", "Voice and text chat software", .communication, 110_000, "0.0.365", true),
            ("slack", "Slack", "Team communication and collaboration software", .communication, 100_000, "4.47", true),
            ("iina", "IINA", "Free and open-source media player", .media, 95_000, "1.4.1", true),
            ("vlc", "VLC media player", "Multimedia player", .media, 90_000, "3.0.21", true),
            ("stats", "Stats", "System monitor for the menu bar", .utilities, 88_000, "2.11.60", true),
            ("figma", "Figma", "Collaborative team software", .design, 80_000, "125.9", true),
            ("blender", "Blender", "3D creation suite", .design, 78_000, "5.0", true),
            ("1password", "1Password", "Password manager that keeps all passwords secure behind one password", .security, 75_000, "8.11", true),
            ("bitwarden", "Bitwarden", "Desktop password and login vault", .security, 60_000, "2026.10", true),
            ("chatgpt", "ChatGPT", "OpenAI's official ChatGPT desktop app", .ai, 160_000, "1.2026.300", false),
            ("claude", "Claude", "Anthropic's official Claude AI desktop app", .ai, 165_000, "1.0.900", false),
            ("steam", "Steam", "Video game digital distribution service", .games, 70_000, "4.0", false),
            ("maccy", "Maccy", "Clipboard manager", .utilities, 65_000, "2.5", true),
            ("notion", "Notion", "App to write, plan, collaborate, and get organised", .productivity, 68_000, "4.20", true),
            ("zed", "Zed", "Multiplayer code editor", .developer, 92_000, "0.212", true),
            ("signal", "Signal", "Instant messaging application focusing on security", .communication, 55_000, "7.78", true),
            ("an-app-with-a-remarkably-long-name", "An App With a Remarkably Long Name for Testing Layouts", "A summary that keeps going well past where a sensible one would stop, to see how cards and rows cope with it", .utilities, 10, "10.20.30", true),
        ]
        return shelf.map { id, name, summary, category, installs, version, hasChecksum in
            StoreApp(
                id: id, name: name, summary: summary, homepage: URL(string: "https://example.com/\(id)"), version: version,
                downloadURL: URL(string: "https://downloads.example.com/\(id).dmg")!,
                checksum: hasChecksum ? String(repeating: "a", count: 64) : nil,
                bundles: [.init(source: "\(name).app", installedName: "\(name).app")], minimumSystem: 14,
                updatesItself: hasChecksum, installs: installs, category: category
            )
        }
    }

    func installedVersion(of app: StoreApp) -> String? { lock.withLock { versions[app.id] } }
    func installedURL(of app: StoreApp) -> URL? { nil }
    func icon(for app: StoreApp) async -> StoreIcon? { nil }

    func install(_ app: StoreApp, onStage: @escaping @Sendable (InstallStage) -> Void) async throws(InstallError) {
        do {
            for step in 0...10 {
                onStage(.downloading(fraction: Double(step) / 10))
                try await Task.sleep(for: .milliseconds(140))
            }
            onStage(.verifying)
            try await Task.sleep(for: .milliseconds(300))
            if fails { throw InstallError.checksumMismatch }
            onStage(.installing)
            try await Task.sleep(for: .milliseconds(500))
        } catch let error as InstallError {
            throw error
        } catch {
            throw .cancelled
        }
        lock.withLock { versions[app.id] = app.displayVersion }
    }

    func uninstall(_ app: StoreApp) throws(InstallError) {
        lock.withLock { versions[app.id] = nil }
    }
}
