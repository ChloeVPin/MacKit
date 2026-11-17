import Foundation
import Synchronization
import Testing
@testable import MacKitCore

@Suite struct CatalogReadingTests {
    private let list = Data(#"""
    [
      {"token":"alpha","name":["Alpha"],"desc":"A plain app","homepage":"https://alpha.example/","url":"https://alpha.example/a.dmg",
       "version":"2.1,99","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
       "artifacts":[{"app":["Alpha.app"]},{"zap":[{"trash":["~/x"]}]}],"depends_on":{"macos":{">=":["14"]}},"auto_updates":true,
       "deprecated":false,"disabled":false,
       "variations":{"golden_gate":{"url":"https://alpha.example/intel.dmg","sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}}},
      {"token":"packaged","name":["Packaged"],"desc":"Needs an installer","homepage":null,"url":"https://p.example/p.pkg",
       "version":"1","sha256":"no_check","artifacts":[{"pkg":["P.pkg"]}],"deprecated":false,"disabled":false},
      {"token":"retired","name":["Retired"],"desc":"Gone","homepage":null,"url":"https://r.example/r.zip",
       "version":"1","sha256":"no_check","artifacts":[{"app":["R.app"]}],"deprecated":true,"disabled":false},
      {"token":"renamed","name":["Renamed"],"desc":"Installs under another name","homepage":null,"url":"https://n.example/n.zip",
       "version":"3","sha256":"no_check","artifacts":[{"app":["Sub/Old.app",{"target":"/Applications/New.app"}]}],"deprecated":false,"disabled":false},
      {"token":"future","name":["Future"],"desc":"Needs a newer macOS","homepage":null,"url":"https://f.example/f.zip",
       "version":"1","sha256":"no_check","artifacts":[{"app":["F.app"]}],"depends_on":{"macos":{">=":["99"]}},"deprecated":false,"disabled":false},
      {"token":"plain-http","name":["Insecure"],"desc":"Not https","homepage":null,"url":"http://i.example/i.zip",
       "version":"1","sha256":"no_check","artifacts":[{"app":["I.app"]}],"deprecated":false,"disabled":false}
    ]
    """#.utf8)
    private let popularity = Data(#"{"items":[{"cask":"alpha","count":"12,345"}]}"#.utf8)

    @Test func `only plain, current, https apps are kept`() throws {
        let apps = try CaskCatalog.apps(list: list, popularity: popularity, platform: .init(systemVersion: 27, isAppleSilicon: true))
        #expect(apps.map(\.id) == ["alpha", "renamed"])
    }

    @Test func `details are read`() throws {
        let alpha = try #require(CaskCatalog.apps(list: list, popularity: popularity, platform: .init(systemVersion: 27, isAppleSilicon: true)).first)
        #expect(alpha.name == "Alpha")
        #expect(alpha.displayVersion == "2.1")
        #expect(alpha.installs == 12_345)
        #expect(alpha.minimumSystem == 14)
        #expect(alpha.updatesItself)
        #expect(alpha.checksum?.hasPrefix("aaaa") == true)
        #expect(alpha.downloadHost == "alpha.example")
    }

    @Test func `an Intel Mac gets the Intel download`() throws {
        let alpha = try #require(CaskCatalog.apps(list: list, popularity: nil, platform: .init(systemVersion: 27, isAppleSilicon: false)).first)
        #expect(alpha.downloadURL.lastPathComponent == "intel.dmg")
        #expect(alpha.checksum?.hasPrefix("bbbb") == true)
    }

    @Test func `no fixed checksum reads as none, and renames are kept`() throws {
        let renamed = try #require(CaskCatalog.apps(list: list, popularity: nil, platform: .init(systemVersion: 27, isAppleSilicon: true)).last)
        #expect(renamed.checksum == nil)
        #expect(renamed.bundles == [.init(source: "Sub/Old.app", installedName: "New.app")])
    }

    @Test(arguments: [("2.10", "2.9", true), ("2.9", "2.10", false), ("1.0", "1.0", false), ("1.0.1", "1.0", true), ("3", "", false)])
    func `versions compare by their numbers`(candidate: String, installed: String, expected: Bool) {
        #expect(isVersion(candidate, newerThan: installed) == expected)
    }

    @Test func `every categorized name is unique`() {
        let names = StoreCategory.members.values.flatMap { $0 }
        #expect(Set(names).count == names.count)
    }

    @Test func `latest version capitalizes cleanly and network errors read in plain English`() {
        let latest = StoreApp(
            id: "demo", name: "Demo", summary: "", homepage: nil, version: "latest",
            downloadURL: URL(string: "https://example.com/demo.dmg")!, checksum: nil,
            bundles: [.init(source: "Demo.app", installedName: "Demo.app")], minimumSystem: nil, updatesItself: true
        )
        #expect(latest.displayVersion == "Latest")
        #expect(!isVersion(latest.displayVersion, newerThan: "1.0"))

        #expect(Downloader.friendlyMessage(for: URLError(.notConnectedToInternet)) == "Check your internet connection and try again.")
        #expect(Downloader.friendlyMessage(for: URLError(.timedOut)) == "The server took too long to respond.")
        #expect(Downloader.friendlyMessage(for: URLError(.cannotFindHost)) == "Couldn't reach the maker's download server.")
        #expect(Downloader.friendlyMessage(for: URLError(.secureConnectionFailed)) == "Couldn't make a secure connection to the download server.")
    }
}

/// Builds a pretend app, packs it the two ways makers ship apps, and
/// installs it into a scratch folder. Nothing is downloaded and the real
/// Applications folder is never touched.
@Suite(.serialized) struct InstallerTests {
    private let root = FileManager.default.temporaryDirectory.appending(path: "MacKitTests-\(UUID().uuidString)", directoryHint: .isDirectory)

    private func run(_ tool: String, _ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        try #require(process.terminationStatus == 0, "\(tool) failed")
    }

    /// Makes `Pretend.app` at the given version and returns its folder.
    private func makeApp(version: String) throws -> URL {
        let folder = root.appending(path: "source-\(version)", directoryHint: .isDirectory)
        let contents = folder.appending(path: "Inner/Pretend.app/Contents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try (["CFBundleShortVersionString": version, "CFBundleIdentifier": "test.pretend"] as NSDictionary)
            .write(to: contents.appending(path: "Info.plist"))
        return folder
    }

    private func app(_ file: URL, checksum: String?) -> StoreApp {
        StoreApp(
            id: "pretend", name: "Pretend", summary: "", homepage: nil, version: "1.0", downloadURL: file, checksum: checksum,
            bundles: [.init(source: "Pretend.app", installedName: "Pretend.app")], minimumSystem: nil, updatesItself: false
        )
    }

    private func installer() throws -> AppInstaller {
        let applications = root.appending(path: "Applications", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: applications, withIntermediateDirectories: true)
        return AppInstaller(applications: applications, checksDeveloper: false)
    }

    /// Downloads from a web server named by `MACKIT_PROGRESS_URL` and checks
    /// that the percentage moves while the file is still arriving.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["MACKIT_PROGRESS_URL"] != nil))
    func `reports progress partway through a web download`() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let url = try #require(URL(string: ProcessInfo.processInfo.environment["MACKIT_PROGRESS_URL"] ?? ""))
        let reported = Mutex<[Double]>([])
        // The file isn't an app, so the install fails after the download.
        try? await installer().install(app(url, checksum: nil)) { stage in
            if case .downloading(let fraction?) = stage { reported.withLock { $0.append(fraction) } }
        }
        let fractions = reported.withLock { $0 }
        #expect(fractions.contains { $0 > 0 && $0 < 1 })
        #expect(fractions.max() == 1)
    }

    @Test func `installs from a zip, checks the checksum, updates, and uninstalls`() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let installer = try installer()

        let zip = root.appending(path: "one.zip")
        try run("/usr/bin/ditto", "-c", "-k", try makeApp(version: "1.0").path(percentEncoded: false), zip.path(percentEncoded: false))
        let checksum = try AppInstaller.sha256(of: zip)

        // A wrong checksum stops the install before anything is copied.
        await #expect(throws: InstallError.checksumMismatch) {
            try await installer.install(app(zip, checksum: String(repeating: "0", count: 64))) { _ in }
        }
        #expect(installer.installedVersion(of: app(zip, checksum: nil)) == nil)

        let reported = Mutex<[Double]>([])
        try await installer.install(app(zip, checksum: checksum)) { stage in
            if case .downloading(let fraction?) = stage { reported.withLock { $0.append(fraction) } }
        }
        #expect(installer.installedVersion(of: app(zip, checksum: nil)) == "1.0")
        // The download reports real progress, not just its starting zero.
        #expect(reported.withLock { $0.max() } == 1)

        // Installing again replaces the copy.
        let newer = root.appending(path: "two.zip")
        try run("/usr/bin/ditto", "-c", "-k", try makeApp(version: "2.0").path(percentEncoded: false), newer.path(percentEncoded: false))
        try await installer.install(app(newer, checksum: nil)) { _ in }
        #expect(installer.installedVersion(of: app(newer, checksum: nil)) == "2.0")

        // Nothing half-installed is left beside it.
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: installer.applications.path(percentEncoded: false))
        #expect(leftovers == ["Pretend.app"])

        try installer.uninstall(app(newer, checksum: nil))
        #expect(installer.installedVersion(of: app(newer, checksum: nil)) == nil)
    }

    @Test func `installs from a disk image and ejects it`() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let installer = try installer()
        let image = root.appending(path: "pretend.dmg")
        try run("/usr/bin/hdiutil", "create", "-srcfolder", try makeApp(version: "3.0").path(percentEncoded: false),
                "-volname", "Pretend", "-format", "UDZO", image.path(percentEncoded: false))

        try await installer.install(app(image, checksum: nil)) { _ in }
        #expect(installer.installedVersion(of: app(image, checksum: nil)) == "3.0")
        #expect(!FileManager.default.fileExists(atPath: "/Volumes/Pretend"))
    }

    @Test func `a download without the app in it fails cleanly`() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let installer = try installer()
        let zip = root.appending(path: "one.zip")
        try run("/usr/bin/ditto", "-c", "-k", try makeApp(version: "1.0").path(percentEncoded: false), zip.path(percentEncoded: false))
        var wrong = app(zip, checksum: nil)
        wrong = StoreApp(
            id: wrong.id, name: wrong.name, summary: "", homepage: nil, version: "1", downloadURL: zip, checksum: nil,
            bundles: [.init(source: "Missing.app", installedName: "Missing.app")], minimumSystem: nil, updatesItself: false
        )
        await #expect(throws: InstallError.appNotFound("Missing.app")) {
            try await installer.install(wrong) { _ in }
        }
    }
}

@Suite(.serialized) struct InstallerSafetyTests {
    private let root = FileManager.default.temporaryDirectory.appending(path: "MacKitSafety-\(UUID().uuidString)", directoryHint: .isDirectory)

    private func run(_ tool: String, _ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        try #require(process.terminationStatus == 0, "\(tool) failed")
    }

    private func makeBundle(at appURL: URL, version: String = "1.0") throws {
        let contents = appURL.appending(path: "Contents/MacOS", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try (["CFBundleShortVersionString": version, "CFBundleIdentifier": "test.pretend"] as NSDictionary)
            .write(to: appURL.appending(path: "Contents/Info.plist"))
        let binary = contents.appending(path: appURL.deletingPathExtension().lastPathComponent)
        try Data("#!/bin/sh\n".utf8).write(to: binary)
        chmod(binary.path(percentEncoded: false), 0o755)
    }

    private func installer() throws -> AppInstaller {
        let applications = root.appending(path: "Applications", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: applications, withIntermediateDirectories: true)
        return AppInstaller(applications: applications, checksDeveloper: false)
    }

    @Test func `malformed checksums and unsafe bundle names are rejected when reading casks`() throws {
        let badList = Data(#"""
        [
          {"token":"bad-hash","name":["BadHash"],"desc":"","homepage":null,"url":"https://a.example/a.zip",
           "version":"1.0","sha256":"12345","artifacts":[{"app":["Bad.app"]}],"deprecated":false,"disabled":false},
          {"token":"non-hex","name":["NonHex"],"desc":"","homepage":null,"url":"https://a.example/b.zip",
           "version":"1.0","sha256":"zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz",
           "artifacts":[{"app":["Bad.app"]}],"deprecated":false,"disabled":false},
          {"token":"dotdot-target","name":["DotDot"],"desc":"","homepage":null,"url":"https://a.example/c.zip",
           "version":"1.0","sha256":"no_check","artifacts":[{"app":["Good.app",{"target":".."}]}],"deprecated":false,"disabled":false},
          {"token":"folder-target","name":["Folder"],"desc":"","homepage":null,"url":"https://a.example/d.zip",
           "version":"1.0","sha256":"no_check","artifacts":[{"app":["Good.app",{"target":"Utilities"}]}],"deprecated":false,"disabled":false}
        ]
        """#.utf8)
        let apps = try CaskCatalog.apps(list: badList, popularity: nil, platform: .init(systemVersion: 27, isAppleSilicon: true))
        #expect(apps.isEmpty)
    }

    @Test func `path traversal in bundle source or installedName is refused`() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let installer = try installer()

        // Place an app outside the archive contents to verify `../../` cannot grab it.
        let outside = root.appending(path: "Outside.app", directoryHint: .isDirectory)
        try makeBundle(at: outside)

        let emptyFolder = root.appending(path: "empty", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true)
        try Data("placeholder".utf8).write(to: emptyFolder.appending(path: "readme.txt"))
        let zip = root.appending(path: "empty.zip")
        try run("/usr/bin/ditto", "-c", "-k", emptyFolder.path(percentEncoded: false), zip.path(percentEncoded: false))

        let escapedSource = StoreApp(
            id: "esc", name: "Esc", summary: "", homepage: nil, version: "1", downloadURL: zip, checksum: nil,
            bundles: [.init(source: "../../Outside.app", installedName: "Outside.app")], minimumSystem: nil, updatesItself: false
        )
        await #expect(throws: InstallError.self) {
            try await installer.install(escapedSource) { _ in }
        }
        #expect(!FileManager.default.fileExists(atPath: installer.applications.appending(path: "Outside.app").path(percentEncoded: false)))

        // Unsafe installedName like ".." or "Utilities" must never trash parent or non-app folders.
        let utilities = installer.applications.appending(path: "Utilities", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: utilities, withIntermediateDirectories: true)
        let badTarget = StoreApp(
            id: "bad", name: "Bad", summary: "", homepage: nil, version: "1", downloadURL: zip, checksum: nil,
            bundles: [.init(source: "Outside.app", installedName: "Utilities")], minimumSystem: nil, updatesItself: false
        )
        #expect(throws: InstallError.self) {
            try installer.uninstall(badTarget)
        }
        #expect(FileManager.default.fileExists(atPath: utilities.path(percentEncoded: false)))
    }

    @Test func `symlinks escaping the app bundle are rejected while internal framework symlinks succeed`() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let installer = try installer()

        let secretFile = root.appending(path: "secret.txt")
        try Data("private".utf8).write(to: secretFile)

        // 1. Top-level .app symlink pointing outside the archive.
        let topSymDir = root.appending(path: "topsym", directoryHint: .isDirectory)
        let victimDir = root.appending(path: "VictimFolder", directoryHint: .isDirectory)
        try makeBundle(at: victimDir)
        try FileManager.default.createDirectory(at: topSymDir, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: topSymDir.appending(path: "Evil.app"), withDestinationURL: victimDir)
        let topSymZip = root.appending(path: "topsym.zip")
        try run("/usr/bin/ditto", "-c", "-k", topSymDir.path(percentEncoded: false), topSymZip.path(percentEncoded: false))

        let topSymApp = StoreApp(
            id: "evil1", name: "Evil1", summary: "", homepage: nil, version: "1", downloadURL: topSymZip, checksum: nil,
            bundles: [.init(source: "Evil.app", installedName: "Evil.app")], minimumSystem: nil, updatesItself: false
        )
        await #expect(throws: InstallError.self) {
            try await installer.install(topSymApp) { _ in }
        }

        // 2. Real .app containing a symlink escaping to `secretFile` (must not touch secretFile's xattrs).
        let innerSymDir = root.appending(path: "innersym", directoryHint: .isDirectory)
        let evilBundle = innerSymDir.appending(path: "Evil2.app", directoryHint: .isDirectory)
        try makeBundle(at: evilBundle)
        try FileManager.default.createSymbolicLink(
            at: evilBundle.appending(path: "Contents/escape"), withDestinationURL: secretFile
        )
        let innerSymZip = root.appending(path: "innersym.zip")
        try run("/usr/bin/ditto", "-c", "-k", innerSymDir.path(percentEncoded: false), innerSymZip.path(percentEncoded: false))

        let innerSymApp = StoreApp(
            id: "evil2", name: "Evil2", summary: "", homepage: nil, version: "1", downloadURL: innerSymZip, checksum: nil,
            bundles: [.init(source: "Evil2.app", installedName: "Evil2.app")], minimumSystem: nil, updatesItself: false
        )
        await #expect(throws: InstallError.self) {
            try await installer.install(innerSymApp) { _ in }
        }
        let checkXattr = Process()
        checkXattr.executableURL = URL(filePath: "/usr/bin/xattr")
        checkXattr.arguments = ["-p", "com.apple.quarantine", secretFile.path(percentEncoded: false)]
        checkXattr.standardOutput = FileHandle.nullDevice
        checkXattr.standardError = FileHandle.nullDevice
        try checkXattr.run()
        checkXattr.waitUntilExit()
        #expect(checkXattr.terminationStatus != 0, "external symlink target must never receive quarantine xattr")

        // 3. Valid internal relative symlink inside Frameworks must still install cleanly.
        let validDir = root.appending(path: "validfw", directoryHint: .isDirectory)
        let validBundle = validDir.appending(path: "Valid.app", directoryHint: .isDirectory)
        try makeBundle(at: validBundle, version: "2.0")
        let versionsA = validBundle.appending(path: "Contents/Frameworks/Helper.framework/Versions/A", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: versionsA, withIntermediateDirectories: true)
        try Data("lib".utf8).write(to: versionsA.appending(path: "Helper"))
        try FileManager.default.createSymbolicLink(
            atPath: validBundle.appending(path: "Contents/Frameworks/Helper.framework/Versions/Current").path(percentEncoded: false),
            withDestinationPath: "A"
        )
        let validZip = root.appending(path: "valid.zip")
        try run("/usr/bin/ditto", "-c", "-k", validDir.path(percentEncoded: false), validZip.path(percentEncoded: false))
        let validApp = StoreApp(
            id: "valid", name: "Valid", summary: "", homepage: nil, version: "2.0", downloadURL: validZip, checksum: nil,
            bundles: [.init(source: "Valid.app", installedName: "Valid.app")], minimumSystem: nil, updatesItself: false
        )
        try await installer.install(validApp) { _ in }
        #expect(installer.installedVersion(of: validApp) == "2.0")
    }

    @Test func `read-only bundles keep quarantine and clean up temporary files`() async throws {
        defer {
            let appsPath = root.appending(path: "Applications/ReadOnly.app").path(percentEncoded: false)
            chmod(appsPath, 0o755)
            chmod(appsPath + "/Contents", 0o755)
            chmod(appsPath + "/Contents/MacOS", 0o755)
            chmod(appsPath + "/Contents/MacOS/ReadOnly", 0o755)
            try? FileManager.default.removeItem(at: root)
        }
        let installer = try installer()

        let srcDir = root.appending(path: "rosrc", directoryHint: .isDirectory)
        let roBundle = srcDir.appending(path: "ReadOnly.app", directoryHint: .isDirectory)
        try makeBundle(at: roBundle, version: "1.0")
        let exePath = roBundle.appending(path: "Contents/MacOS/ReadOnly").path(percentEncoded: false)
        let macosPath = roBundle.appending(path: "Contents/MacOS").path(percentEncoded: false)
        let contentsPath = roBundle.appending(path: "Contents").path(percentEncoded: false)
        let bundlePath = roBundle.path(percentEncoded: false)
        chmod(exePath, 0o555)
        chmod(macosPath, 0o555)
        chmod(contentsPath, 0o555)
        chmod(bundlePath, 0o555)

        let roZip = root.appending(path: "ro.zip")
        try run("/usr/bin/ditto", "-c", "-k", srcDir.path(percentEncoded: false), roZip.path(percentEncoded: false))
        chmod(bundlePath, 0o755); chmod(contentsPath, 0o755); chmod(macosPath, 0o755); chmod(exePath, 0o755)

        let roApp = StoreApp(
            id: "readonly", name: "ReadOnly", summary: "", homepage: nil, version: "1.0", downloadURL: roZip, checksum: nil,
            bundles: [.init(source: "ReadOnly.app", installedName: "ReadOnly.app")], minimumSystem: nil, updatesItself: false
        )
        try await installer.install(roApp) { _ in }

        let installedApp = installer.applications.appending(path: "ReadOnly.app")
        let installedExe = installedApp.appending(path: "Contents/MacOS/ReadOnly")
        for target in [installedApp, installedExe] {
            let p = Process()
            p.executableURL = URL(filePath: "/usr/bin/xattr")
            p.arguments = ["-s", "-p", "com.apple.quarantine", target.path(percentEncoded: false)]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = FileHandle.nullDevice
            try p.run()
            p.waitUntilExit()
            let value = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            #expect(p.terminationStatus == 0, "quarantine missing on \(target.lastPathComponent)")
            #expect(value.hasPrefix("0081;"), "unexpected quarantine value \(value)")
        }
    }

    @Test func `failed multi-bundle update keeps the previous version intact and unwritable Applications fails before download`() async throws {
        defer {
            chmod(root.appending(path: "LockedApps").path(percentEncoded: false), 0o755)
            try? FileManager.default.removeItem(at: root)
        }
        let installer = try installer()

        // Install v1.0 of SuiteA.app first.
        let v1Dir = root.appending(path: "v1", directoryHint: .isDirectory)
        try makeBundle(at: v1Dir.appending(path: "SuiteA.app"), version: "1.0")
        try makeBundle(at: v1Dir.appending(path: "SuiteB.app"), version: "1.0")
        let v1Zip = root.appending(path: "v1.zip")
        try run("/usr/bin/ditto", "-c", "-k", v1Dir.path(percentEncoded: false), v1Zip.path(percentEncoded: false))

        let suiteV1 = StoreApp(
            id: "suite", name: "Suite", summary: "", homepage: nil, version: "1.0", downloadURL: v1Zip, checksum: nil,
            bundles: [
                .init(source: "SuiteA.app", installedName: "SuiteA.app"),
                .init(source: "SuiteB.app", installedName: "SuiteB.app"),
            ],
            minimumSystem: nil, updatesItself: false
        )
        try await installer.install(suiteV1) { _ in }
        #expect(installer.installedVersion(of: suiteV1) == "1.0")

        // v2.0 archive is missing SuiteB.app -> update fails partway and must leave SuiteA.app at 1.0!
        let v2Dir = root.appending(path: "v2", directoryHint: .isDirectory)
        try makeBundle(at: v2Dir.appending(path: "SuiteA.app"), version: "2.0")
        let v2Zip = root.appending(path: "v2.zip")
        try run("/usr/bin/ditto", "-c", "-k", v2Dir.path(percentEncoded: false), v2Zip.path(percentEncoded: false))

        let suiteV2 = StoreApp(
            id: "suite", name: "Suite", summary: "", homepage: nil, version: "2.0", downloadURL: v2Zip, checksum: nil,
            bundles: suiteV1.bundles, minimumSystem: nil, updatesItself: false
        )
        await #expect(throws: InstallError.appNotFound("SuiteB.app")) {
            try await installer.install(suiteV2) { _ in }
        }
        #expect(installer.installedVersion(of: suiteV1) == "1.0")

        // Unwritable Applications folder (non-admin user) fails immediately without downloading, and plain http is refused.
        let lockedApps = root.appending(path: "LockedApps", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: lockedApps, withIntermediateDirectories: true)
        chmod(lockedApps.path(percentEncoded: false), 0o555)
        let nonAdminInstaller = AppInstaller(applications: lockedApps, checksDeveloper: false)
        let didStartDownload = Mutex(false)
        await #expect(throws: InstallError.self) {
            try await nonAdminInstaller.install(suiteV1) { stage in
                if case .downloading = stage { didStartDownload.withLock { $0 = true } }
            }
        }
        #expect(!didStartDownload.withLock { $0 })

        let insecureApp = StoreApp(
            id: "http", name: "HTTP", summary: "", homepage: nil, version: "1.0",
            downloadURL: URL(string: "http://127.0.0.1:9/evil.zip")!, checksum: nil,
            bundles: [.init(source: "SuiteA.app", installedName: "SuiteA.app")], minimumSystem: nil, updatesItself: false
        )
        await #expect(throws: InstallError.self) {
            try await installer.install(insecureApp) { _ in }
        }
    }

    @Test func `offline icon lookups do not poison the disk cache and negative markers expire`() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = root.appending(path: "Icons", directoryHint: .isDirectory)
        let sample = StoreApp(
            id: "offline-demo", name: "Offline Demo", summary: "", homepage: URL(string: "https://demo.example/"),
            version: "1.0", downloadURL: URL(string: "https://demo.example/demo.dmg")!, checksum: nil,
            bundles: [.init(source: "Demo.app", installedName: "Demo.app")], minimumSystem: nil, updatesItself: false
        )

        // Offline: every network request fails without an HTTP response -> must NOT write `.none`.
        let offline = await IconFinder.lookup(for: sample) { _ in nil }
        if case .unreachable = offline {} else { Issue.record("Expected .unreachable when offline") }
        IconFinder.writeCache(offline, for: sample.id, in: cache)
        #expect(IconFinder.readCache(for: sample.id, in: cache) == nil)

        // Online 404: servers answered and had no icon -> writes `.none`, which expires after 24 hours.
        let notFound = await IconFinder.lookup(for: sample) { _ in (Data(), 404) }
        if case .noneFound = notFound {} else { Issue.record("Expected .noneFound when servers answered 404") }
        IconFinder.writeCache(notFound, for: sample.id, in: cache)
        #expect(IconFinder.readCache(for: sample.id, in: cache) == .missing)
        let tomorrow = Date.now.addingTimeInterval(IconFinder.negativeCacheLifetime + 60)
        #expect(IconFinder.readCache(for: sample.id, in: cache, now: tomorrow) == nil)
    }
}

/// Reads a saved copy of the real list. Off unless `MACKIT_CASKS` names a
/// folder holding `cask.json` and `an.json`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MACKIT_CASKS"] != nil))
struct RealCatalogTests {
    @Test func `the real list reads`() throws {
        let folder = URL(filePath: ProcessInfo.processInfo.environment["MACKIT_CASKS"]!)
        let clock = ContinuousClock()
        var apps: [StoreApp] = []
        let elapsed = try clock.measure {
            apps = try CaskCatalog.apps(
                list: Data(contentsOf: folder.appending(path: "cask.json")),
                popularity: try? Data(contentsOf: folder.appending(path: "an.json"))
            )
        }
        print("REAL \(apps.count) apps in \(elapsed); with checksum \(apps.count { $0.checksum != nil }); categorized \(apps.count { $0.category != nil })")
        let uncategorized = Set(StoreCategory.members.values.flatMap { $0 }).subtracting(apps.map(\.id))
        print("REAL names in categories but not installable here: \(uncategorized.sorted())")
        print("REAL top: \(apps.sorted { $0.installs > $1.installs }.prefix(12).map(\.id))")
        #expect(apps.count > 1000)
    }
}

/// Times fetching the real list. Off unless `MACKIT_NET=1`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MACKIT_NET"] == "1"))
struct NetworkTimingTests {
    @Test func `fetching the list`() async throws {
        let clock = ContinuousClock()
        var start = clock.now
        let (list, _) = try await URLSession.shared.data(from: CaskCatalog.listURL)
        print("NET list \(list.count) bytes in \(clock.now - start)")
        start = clock.now
        let popularity = try await URLSession.shared.data(from: CaskCatalog.popularityURL).0
        print("NET popularity \(popularity.count) bytes in \(clock.now - start)")
    }
}

/// Measures how many apps get an icon, over a sample of the real list.
/// Off unless `MACKIT_ICONS` names the folder holding `cask.json`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MACKIT_ICONS"] != nil))
struct IconCoverageTests {
    @Test func `icon coverage`() async throws {
        let folder = URL(filePath: ProcessInfo.processInfo.environment["MACKIT_ICONS"]!)
        let apps = try CaskCatalog.apps(
            list: Data(contentsOf: folder.appending(path: "cask.json")),
            popularity: try? Data(contentsOf: folder.appending(path: "an.json"))
        ).sorted { $0.installs > $1.installs }
        // The 150 most popular, then every 20th of the rest.
        let sample = Array(apps.prefix(150)) + stride(from: 150, to: apps.count, by: 20).map { apps[$0] }

        var results: [(StoreApp, FoundIcon?)] = []
        await withTaskGroup(of: (StoreApp, FoundIcon?).self) { group in
            var waiting = sample.makeIterator()
            for _ in 0..<12 { if let app = waiting.next() { group.addTask { (app, await IconFinder.find(for: app)) } } }
            for await result in group {
                results.append(result)
                if let app = waiting.next() { group.addTask { (app, await IconFinder.find(for: app)) } }
            }
        }
        func report(_ name: String, _ part: [(StoreApp, FoundIcon?)]) {
            let sharp = part.count { ($0.1?.pixels ?? 0) >= IconFinder.sharpEnough }
            let small = part.count { $0.1 != nil } - sharp
            let sources = FoundIcon.Source.allCases.map { source in "\(source.rawValue) \(part.count { $0.1?.source == source })" }
            print("ICONS \(name): \(part.count) apps, sharp \(sharp), small \(small), none \(part.count - sharp - small) | \(sources.joined(separator: ", "))")
        }
        let top = Set(sample.prefix(150).map(\.id))
        report("top 150", results.filter { top.contains($0.0.id) })
        report("the rest", results.filter { !top.contains($0.0.id) })
        print("ICONS none: \(results.filter { $0.1 == nil }.map { "\($0.0.id) [\($0.0.homepage?.host() ?? "-")]" }.sorted().prefix(40))")
    }
}
