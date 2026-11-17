import Darwin
import Foundation
import Testing
@testable import MacKitCore

/// Runs administrator changes for real, as root, and puts them back.
///
/// **This changes real settings.** It is meant for a virtual machine you can
/// throw away, and refuses to run anywhere else:
///
///     MACKIT_LIVE_ADMIN=1 swift test --package-path Packages/MacKitCore --filter LiveAdminTests
///
/// macOS asks for an administrator password three times: once for the
/// batch check, once to apply, once to undo. To run on a real Mac anyway,
/// knowing what that means, set `MACKIT_LIVE_ADMIN=this-mac`.
///
/// What it touches, each restored afterwards:
/// - Touch ID for sudo (`/etc/pam.d/sudo_local`). If the file didn't exist it
///   is left behind with the line commented out, which is Apple's template.
/// - Turn display off after, when plugged in (`pmset -c displaysleep`).
/// - Wi-Fi sign-in window (a root-owned preference file written directly).
///
/// If the run stops halfway, the lines printed as `BEFORE` say what each
/// setting was, so it can be put back by hand in MacKit or System Settings.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MACKIT_LIVE_ADMIN"] != nil), .serialized)
struct LiveAdminTests {
    /// Asks for an administrator password the way the app does: the same
    /// script, through `do shell script … with administrator privileges`.
    struct PromptRunner: PrivilegedRunning {
        func runAsAdministrator(_ commands: [Command]) async throws(SystemError) {
            let outcomes = try await runAsAdministrator([PrivilegedGroup(id: "_batch", commands: commands)])
            if case .failure(let error)? = outcomes["_batch"] { throw error }
        }

        func runAsAdministrator(_ groups: [PrivilegedGroup]) async throws(SystemError) -> [Tweak.ID: Result<Void, SystemError>] {
            let literal = PrivilegedBatchScript.build(for: groups)
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let source = "do shell script \"\(literal)\" with prompt \"MacKit's test needs an administrator password.\" with administrator privileges"

            let process = Process()
            let out = Pipe(), err = Pipe()
            process.executableURL = URL(filePath: "/usr/bin/osascript")
            process.arguments = ["-e", source]
            process.standardOutput = out
            process.standardError = err
            do { try process.run() } catch {
                throw SystemError.launchFailed(command: "osascript", message: error.localizedDescription)
            }
            let output = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            let message = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw message.contains("-128") ? SystemError.authorizationCancelled : .authorizationFailed(message)
            }
            return PrivilegedBatchScript.parse(output, for: groups)
        }
    }

    static var isVirtualMachine: Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("kern.hv_vmm_present", &value, &size, nil, 0) == 0 && value == 1
    }

    /// Whether this run is allowed to change settings on this machine.
    static func mayRun() -> Bool {
        if isVirtualMachine || ProcessInfo.processInfo.environment["MACKIT_LIVE_ADMIN"] == "this-mac" { return true }
        Issue.record("This is not a virtual machine, so nothing was changed. See the note at the top of LiveAdminTests.swift.")
        return false
    }

    @Test func `one failing change in a batch doesn't stop the others, as root`() async throws {
        guard Self.mayRun() else { return }
        // Harmless commands: nothing is written.
        let groups = [
            PrivilegedGroup(id: "root", commands: [Command("/bin/sh", "-c", "[ \"$(/usr/bin/id -u)\" = 0 ]")]),
            PrivilegedGroup(id: "fails", commands: [Command("/bin/sh", "-c", "echo 'not allowed' >&2; exit 7")]),
            PrivilegedGroup(id: "after", commands: [Command("/usr/bin/true")]),
        ]
        let outcomes = try await PromptRunner().runAsAdministrator(groups)
        if case .failure(let error)? = outcomes["root"] { Issue.record("The script didn't run as root: \(error)") }
        if case .failure(.commandFailed(_, let code, let message))? = outcomes["fails"] {
            #expect(code == 7)
            #expect(message.contains("not allowed"))
        } else {
            Issue.record("The failing change wasn't reported as failed")
        }
        if case .failure(let error)? = outcomes["after"] { Issue.record("The change after the failure was skipped: \(error)") }
    }

    @Test func `administrator settings apply, read back, and undo exactly`() async throws {
        guard Self.mayRun() else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let access = SystemAccess(
            preferences: SystemPreferenceStore(), commands: AllowlistedCommandRunner(),
            privileged: PromptRunner(), fileFlags: SystemFileFlagStore(), homeDirectory: home
        )
        let engine = TweakEngine(system: access)
        let catalog = Catalog.tweaks(home: home)

        // Each setting moves to an option it isn't in. One that can't be
        // read as a known option on this machine is left alone.
        var requests: [(tweak: Tweak, option: TweakOption.ID)] = []
        var before: [Tweak.ID: TweakState] = [:]
        for id in ["security.touch-id-sudo", "power.adapter.display", "network.captive-portal"] {
            let tweak = try #require(catalog.first { $0.id == id })
            let state = await engine.state(of: tweak)
            print("BEFORE \(id) \(state)")
            guard case .option(let current) = state,
                  let other = tweak.options.first(where: { $0.id != current && $0.id != "never" }) else {
                print("SKIPPED \(id)")
                continue
            }
            before[id] = state
            requests.append((tweak, other.id))
        }
        try #require(!requests.isEmpty, "No setting could be read on this machine")

        // Apply: one password prompt for all of them.
        let results = await engine.apply(engine.plan(requests))
        var undo: [(tweak: Tweak, snapshot: Snapshot)] = []
        for (request, result) in zip(requests, results) {
            #expect(result.outcome == .applied, "\(request.tweak.id): \(result.outcome)")
            if let snapshot = result.snapshot { undo.append((request.tweak, snapshot)) }
            let now = await engine.state(of: request.tweak)
            print("APPLIED \(request.tweak.id) \(now)")
            if result.outcome.isApplied {
                #expect(now == .option(request.option), "\(request.tweak.id) didn't read back as \(request.option)")
            }
        }

        // Files root wrote must stay readable by everyone else.
        func mode(_ path: String) -> Int? {
            (try? FileManager.default.attributesOfItem(atPath: path))?[.posixPermissions] as? Int
        }
        if requests.contains(where: { $0.tweak.id == "security.touch-id-sudo" }) {
            #expect(mode("/etc/pam.d/sudo_local") == 0o444)
            // sudo must still parse its configuration.
            let sudo = Process()
            sudo.executableURL = URL(filePath: "/usr/bin/sudo")
            sudo.arguments = ["-n", "-k", "/usr/bin/true"]
            sudo.standardOutput = FileHandle.nullDevice
            let complaint = Pipe()
            sudo.standardError = complaint
            try sudo.run()
            let text = String(decoding: complaint.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            sudo.waitUntilExit()
            #expect(!text.lowercased().contains("pam") && !text.lowercased().contains("syntax"), "sudo complained: \(text)")
        }
        if requests.contains(where: { $0.tweak.id == "network.captive-portal" }) {
            #expect(mode("/Library/Preferences/SystemConfiguration/com.apple.captive.control.plist") == 0o644)
        }

        // Undo from the snapshots: the second password prompt.
        let reverted = await engine.apply(engine.revertPlan(undo))
        for result in reverted {
            #expect(result.outcome == .applied, "undo \(result.id): \(result.outcome)")
        }
        for request in requests {
            let now = await engine.state(of: request.tweak)
            print("AFTER \(request.tweak.id) \(now)")
            #expect(now == before[request.tweak.id], "\(request.tweak.id) wasn't put back")
        }
    }
}
