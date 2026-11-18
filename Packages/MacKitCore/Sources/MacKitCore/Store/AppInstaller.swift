import CryptoKit
import Foundation
import Synchronization

public enum InstallStage: Hashable, Sendable {
    /// `fraction` is `nil` when the server doesn't say how big the file is.
    case downloading(fraction: Double?)
    case verifying
    case installing
}

public enum InstallError: Error, Hashable, Sendable {
    case downloadFailed(String)
    /// The file isn't the one the catalog describes.
    case checksumMismatch
    case unsupportedDownload
    case appNotFound(String)
    /// macOS doesn't trust the app: it isn't signed by an identified
    /// developer and checked by Apple.
    case notTrusted(String)
    case copyFailed(String)
    case cancelled

    public var explanation: String {
        switch self {
        case .downloadFailed(let message): "The download didn't finish. \(message)"
        case .checksumMismatch: "The download doesn't match what its maker published, so it wasn't installed."
        case .unsupportedDownload: "This download is in a format MacKit can't open."
        case .appNotFound(let name): "The download didn't contain \(name)."
        case .notTrusted(let name): "macOS couldn't confirm \(name) comes from an identified developer, so it wasn't installed."
        case .copyFailed(let message): "Couldn't put the app in Applications. \(message)"
        case .cancelled: "Cancelled."
        }
    }
}

/// Downloads an app from its maker and puts it in the Applications folder.
///
/// The steps mirror what a careful person does by hand: download, check the
/// file is the right one, open the disk image or archive, let macOS check
/// who made the app, then copy it into place. An app that is already
/// installed goes to the Trash first, so nothing is lost.
public struct AppInstaller: Sendable {
    /// Where apps are installed.
    public var applications: URL
    /// Whether macOS has to confirm the developer before the app is
    /// installed. Only tests turn this off.
    public var checksDeveloper: Bool

    public init(applications: URL = URL(filePath: "/Applications", directoryHint: .isDirectory), checksDeveloper: Bool = true) {
        self.applications = applications
        self.checksDeveloper = checksDeveloper
    }

    // MARK: Reading what's installed

    public func installedURL(of app: StoreApp) -> URL? {
        guard let bundle = app.bundles.first, StoreApp.Bundle.isValidBundleName(bundle.installedName) else { return nil }
        let url = applications.appending(path: bundle.installedName, directoryHint: .isDirectory)
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }

    /// The version of the copy in Applications, or `nil` if there isn't one.
    public func installedVersion(of app: StoreApp) -> String? {
        guard let url = installedURL(of: app) else { return nil }
        let info = NSDictionary(contentsOf: url.appending(path: "Contents/Info.plist"))
        return (info?["CFBundleShortVersionString"] as? String) ?? (info?["CFBundleVersion"] as? String) ?? ""
    }

    // MARK: Installing

    @concurrent
    public func install(_ app: StoreApp, onStage: @escaping @Sendable (InstallStage) -> Void) async throws(InstallError) {
        let files = FileManager.default
        guard !app.bundles.isEmpty, app.bundles.allSatisfy(\.isSafe) else {
            throw .copyFailed("The app's bundle name isn't safe to install.")
        }
        guard files.isWritableFile(atPath: applications.path(percentEncoded: false)) else {
            throw .copyFailed("Your Mac account doesn't have permission to change the Applications folder. Sign in to an administrator account to install apps.")
        }

        let work = files.temporaryDirectory.appending(path: "MacKit-\(UUID().uuidString)", directoryHint: .isDirectory)
        do {
            try files.createDirectory(at: work, withIntermediateDirectories: true)
        } catch {
            throw .copyFailed(error.localizedDescription)
        }
        defer { Self.removeCleanly(work) }

        onStage(.downloading(fraction: 0))
        let download = work.appending(path: "download")
        try await Downloader.download(app.downloadURL, to: download) { onStage(.downloading(fraction: $0)) }

        onStage(.verifying)
        if let expected = app.checksum, try Self.sha256(of: download) != expected {
            throw .checksumMismatch
        }

        // Quarantine the downloaded archive before opening it so `ditto`,
        // `tar`, and `hdiutil` propagate Gatekeeper's flag onto read-only
        // files inside the bundle too.
        let stamp = String(Int(Date.now.timeIntervalSince1970), radix: 16)
        // 0x0001 and 0x0080 are the ordinary "downloaded, not yet approved"
        // flags, so Gatekeeper still checks the app the first time it opens.
        // 0x0100 says the app was put in place by an installer. Without it
        // macOS runs a quarantined app from a hidden read-only copy (App
        // Translocation), where its own updater can't write: Discord then
        // asks to install a helper in a loop.
        let quarantine = "0181;\(stamp);MacKit;"
        let markedDownload = await Self.run("/usr/bin/xattr", ["-s", "-w", "com.apple.quarantine", quarantine, download.path(percentEncoded: false)])
        guard markedDownload.status == 0 else {
            throw .copyFailed("Couldn't mark the download for macOS security checks.")
        }

        onStage(.installing)
        let contents = work.appending(path: "contents", directoryHint: .isDirectory)
        let mounted = try await Self.open(download, into: contents)
        defer {
            if mounted { Self.runDetached("/usr/bin/hdiutil", ["detach", contents.path(percentEncoded: false), "-force", "-quiet"]) }
        }
        if Task.isCancelled { throw .cancelled }

        // Stage and verify every bundle before replacing anything in Applications.
        var stagedBundles: [(staged: URL, target: URL)] = []
        defer {
            for item in stagedBundles { Self.removeCleanly(item.staged) }
        }
        for bundle in app.bundles {
            guard let source = Self.find(bundle.source, in: contents) else { throw .appNotFound(bundle.source) }
            try Self.verifySafeBundle(at: source, inside: contents, name: bundle.installedName)
            let staged = try await stage(source, as: bundle.installedName, quarantine: quarantine)
            let target = applications.appending(path: bundle.installedName, directoryHint: .isDirectory)
            stagedBundles.append((staged, target))
        }
        if Task.isCancelled { throw .cancelled }

        var replaced: [(target: URL, trashed: URL?)] = []
        do {
            for item in stagedBundles {
                var trashed: URL?
                if files.fileExists(atPath: item.target.path(percentEncoded: false)) {
                    var resulting: NSURL?
                    try files.trashItem(at: item.target, resultingItemURL: &resulting)
                    trashed = resulting as URL?
                }
                do {
                    try files.moveItem(at: item.staged, to: item.target)
                    replaced.append((item.target, trashed))
                } catch {
                    if let trashed { try? files.moveItem(at: trashed, to: item.target) }
                    throw error
                }
            }
        } catch {
            for item in replaced.reversed() {
                Self.removeCleanly(item.target)
                if let trashed = item.trashed { try? files.moveItem(at: trashed, to: item.target) }
            }
            throw .copyFailed(error.localizedDescription)
        }
    }

    /// Moves the installed copy to the Trash.
    public func uninstall(_ app: StoreApp) throws(InstallError) {
        guard !app.bundles.isEmpty, app.bundles.allSatisfy(\.isSafe) else {
            throw .copyFailed("The app's bundle name isn't safe to remove.")
        }
        guard FileManager.default.isWritableFile(atPath: applications.path(percentEncoded: false)) else {
            throw .copyFailed("Your Mac account doesn't have permission to change the Applications folder. Sign in to an administrator account to remove apps.")
        }
        for bundle in app.bundles {
            let url = applications.appending(path: bundle.installedName, directoryHint: .isDirectory)
            guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { continue }
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                throw .copyFailed(error.localizedDescription)
            }
        }
    }

    private func stage(_ source: URL, as name: String, quarantine: String) async throws(InstallError) -> URL {
        // Copy beside the final location first, so a failure halfway never
        // leaves a broken app where a working one was.
        let staged = applications.appending(path: ".\(name).installing-\(UUID().uuidString.prefix(8))", directoryHint: .isDirectory)

        let copy = await Self.run("/usr/bin/ditto", [source.path(percentEncoded: false), staged.path(percentEncoded: false)])
        guard copy.status == 0 else {
            Self.removeCleanly(staged)
            throw .copyFailed(copy.output)
        }

        // Refresh quarantine on writable entries without following symlinks,
        // then confirm the bundle and its main executable carry Gatekeeper's
        // unapproved download flag.
        _ = await Self.run("/usr/bin/xattr", ["-r", "-s", "-w", "com.apple.quarantine", quarantine, staged.path(percentEncoded: false)])
        guard await Self.hasQuarantine(staged) else {
            Self.removeCleanly(staged)
            throw .copyFailed("macOS couldn't keep the security quarantine attribute on \(name).")
        }

        if checksDeveloper {
            let verdict = await Self.run("/usr/sbin/spctl", ["--assess", "--type", "execute", staged.path(percentEncoded: false)])
            guard verdict.status == 0 else {
                Self.removeCleanly(staged)
                throw .notTrusted(name)
            }
        }
        return staged
    }

    private static func hasQuarantine(_ bundle: URL) async -> Bool {
        var targets = [bundle]
        if let info = NSDictionary(contentsOf: bundle.appending(path: "Contents/Info.plist")),
           let execName = info["CFBundleExecutable"] as? String, !execName.isEmpty, !execName.contains("/") {
            let execURL = bundle.appending(path: "Contents/MacOS/\(execName)")
            if FileManager.default.fileExists(atPath: execURL.path(percentEncoded: false)) {
                targets.append(execURL)
            }
        }
        for target in targets {
            let check = await run("/usr/bin/xattr", ["-s", "-p", "com.apple.quarantine", target.path(percentEncoded: false)])
            guard check.status == 0, let flagsHex = check.output.split(separator: ";").first,
                  let flags = UInt32(flagsHex, radix: 16), (flags & 0x0040) == 0 else {
                return false
            }
        }
        return true
    }

    /// Ensures `bundle` is a real directory inside `container` and every
    /// symbolic link inside it resolves strictly within `bundle`.
    private static func verifySafeBundle(at bundle: URL, inside container: URL, name: String) throws(InstallError) {
        let files = FileManager.default
        guard (try? bundle.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == false else {
            throw .notTrusted(name)
        }
        var isDirectory: ObjCBool = false
        guard files.fileExists(atPath: bundle.path(percentEncoded: false), isDirectory: &isDirectory), isDirectory.boolValue else {
            throw .notTrusted(name)
        }
        let containerPrefix = container.resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false).trimmingSuffix("/") + "/"
        let bundleRoot = bundle.resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false).trimmingSuffix("/")
        guard bundleRoot.hasPrefix(containerPrefix) else {
            throw .notTrusted(name)
        }
        let allowedPrefix = bundleRoot + "/"

        guard let enumerator = files.enumerator(at: bundle, includingPropertiesForKeys: [.isSymbolicLinkKey]) else {
            throw .copyFailed("Couldn't inspect \(name) before installing.")
        }
        for case let entry as URL in enumerator {
            guard (try? entry.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true else { continue }
            let entryPath = entry.path(percentEncoded: false)
            guard let target = try? files.destinationOfSymbolicLink(atPath: entryPath), !target.hasPrefix("/") else {
                throw .notTrusted(name)
            }
            let lexical = URL(filePath: target, relativeTo: entry.deletingLastPathComponent()).standardizedFileURL.path(percentEncoded: false)
            let resolved = entry.resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false)
            guard lexical.hasPrefix(allowedPrefix), resolved.hasPrefix(allowedPrefix) else {
                throw .notTrusted(name)
            }
        }
    }

    /// Removes a temporary directory or staged bundle even when an archive
    /// extracted read-only (`0555`) folders inside it.
    private static func removeCleanly(_ url: URL) {
        let files = FileManager.default
        if (try? files.removeItem(at: url)) != nil { return }
        let rootPath = url.path(percentEncoded: false)
        guard files.fileExists(atPath: rootPath) else { return }
        if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true {
            chmod(rootPath, 0o700)
            if let enumerator = files.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) {
                for case let item as URL in enumerator {
                    let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                    if values?.isSymbolicLink != true, values?.isDirectory == true {
                        chmod(item.path(percentEncoded: false), 0o700)
                    }
                }
            }
        }
        try? files.removeItem(at: url)
    }

    // MARK: Opening the download

    private enum Kind {
        case diskImage, zip, tar
    }

    /// Works out what the file is from its contents, since download links
    /// often have no file extension.
    private static func kind(of file: URL) -> Kind? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        let head = (try? handle.read(upToCount: 6)) ?? Data()
        if head.starts(with: [0x50, 0x4B]) { return .zip }
        if head.starts(with: [0x1F, 0x8B]) || head.starts(with: [0xFD, 0x37, 0x7A, 0x58]) || head.starts(with: [0x42, 0x5A, 0x68]) {
            return .tar
        }
        // A disk image ends with a 512-byte trailer that starts "koly".
        if let size = try? handle.seekToEnd(), size > 512, (try? handle.seek(toOffset: size - 512)) != nil,
           let trailer = try? handle.read(upToCount: 4), trailer == Data("koly".utf8) {
            return .diskImage
        }
        return nil
    }

    /// Makes the download's contents available in `folder`. Returns whether
    /// a disk image was mounted there and needs ejecting afterwards.
    private static func open(_ file: URL, into folder: URL) async throws(InstallError) -> Bool {
        let (path, destination) = (file.path(percentEncoded: false), folder.path(percentEncoded: false))
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw .copyFailed(error.localizedDescription)
        }
        switch kind(of: file) {
        case .zip:
            let result = await run("/usr/bin/ditto", ["-x", "-k", path, destination])
            guard result.status == 0 else { throw .unsupportedDownload }
            return false
        case .tar:
            let result = await run("/usr/bin/tar", ["-xf", path, "-C", destination])
            guard result.status == 0 else { throw .unsupportedDownload }
            return false
        case .diskImage, nil:
            // Unknown files get one try as a disk image: some use formats
            // without the usual trailer.
            let result = await run("/usr/bin/hdiutil", ["attach", path, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", destination])
            guard result.status == 0 else { throw .unsupportedDownload }
            return true
        }
    }

    /// Finds a bundle by name, looking a few folders deep. Disk images often
    /// tuck the app inside a folder.
    private static func find(_ name: String, in folder: URL) -> URL? {
        let direct = folder.appending(path: name)
        if (try? FileManager.default.attributesOfItem(atPath: direct.path(percentEncoded: false))) != nil { return direct }
        let wanted = (name as NSString).lastPathComponent
        guard let walker = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return nil }
        for case let url as URL in walker {
            if walker.level > 3 { walker.skipDescendants(); continue }
            if url.lastPathComponent == wanted { return url }
        }
        return nil
    }

    static func sha256(of file: URL) throws(InstallError) -> String {
        guard let handle = try? FileHandle(forReadingFrom: file) else { throw .downloadFailed("The file couldn't be read.") }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Running system tools

    private static func run(_ tool: String, _ arguments: [String]) async -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        let status: Int32 = await withCheckedContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(returning: -1)
            }
        }
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return (status, output.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Starts a tool without waiting, for cleanup that runs as a scope ends.
    private static func runDetached(_ tool: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}

/// Downloads one file, reporting how far along it is.
///
/// The session's own delegate is used, not a per-download one: macOS only
/// reports progress and the finished file to the session's delegate.
final class Downloader: NSObject, URLSessionDownloadDelegate, Sendable {
    private struct State {
        var continuation: CheckedContinuation<Void, any Error>?
        var failure: (any Error)?
    }

    private let destination: URL
    private let onProgress: @Sendable (Double?) -> Void
    private let state = Mutex(State())

    private init(destination: URL, onProgress: @escaping @Sendable (Double?) -> Void) {
        self.destination = destination
        self.onProgress = onProgress
    }

    static func download(_ url: URL, to destination: URL, onProgress: @escaping @Sendable (Double?) -> Void) async throws(InstallError) {
        guard url.scheme == "https" || url.isFileURL else {
            throw .downloadFailed("The download address doesn't use a secure HTTPS connection.")
        }
        let downloader = Downloader(destination: destination, onProgress: onProgress)
        let session = URLSession(configuration: .ephemeral, delegate: downloader, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let task = session.downloadTask(with: url)
        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    downloader.state.withLock { $0.continuation = continuation }
                    task.resume()
                }
            } onCancel: {
                task.cancel()
            }
        } catch let error as InstallError {
            throw error
        } catch is CancellationError {
            throw .cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw .cancelled
        } catch {
            throw .downloadFailed(friendlyMessage(for: error))
        }
    }

    static func friendlyMessage(for error: any Error) -> String {
        guard let urlError = error as? URLError else { return error.localizedDescription }
        return switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            "Check your internet connection and try again."
        case .timedOut:
            "The server took too long to respond."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            "Couldn't reach the maker's download server."
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
             .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid:
            "Couldn't make a secure connection to the download server."
        default:
            urlError.localizedDescription
        }
    }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        onProgress(totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : nil)
    }

    // The file is deleted as soon as this returns, so it is moved here.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let failure: (any Error)?
        if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            failure = InstallError.downloadFailed("The server answered with error \(http.statusCode).")
        } else {
            do {
                try FileManager.default.moveItem(at: location, to: destination)
                failure = nil
            } catch {
                failure = error
            }
        }
        state.withLock { $0.failure = failure }
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        guard request.url?.scheme == "https" else {
            state.withLock { $0.failure = InstallError.downloadFailed("The download server redirected to an unencrypted connection.") }
            task.cancel()
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let (continuation, failure) = state.withLock { state in
            defer { state.continuation = nil }
            return (state.continuation, state.failure)
        }
        if let problem = failure ?? error {
            continuation?.resume(throwing: problem)
        } else {
            continuation?.resume()
        }
    }
}
