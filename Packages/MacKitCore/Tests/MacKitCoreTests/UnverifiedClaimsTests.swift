import Foundation
import Testing
@testable import MacKitCore

private let home = URL(filePath: "/Users/sample")

/// Runs a command as the current user and returns what it printed.
private func run(_ executable: String, _ arguments: [String]) throws -> CommandOutput {
    let process = Process()
    let out = Pipe(), err = Pipe()
    process.executableURL = URL(filePath: executable)
    process.arguments = arguments
    process.standardOutput = out
    process.standardError = err
    try process.run()
    let output = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    let error = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    process.waitUntilExit()
    return CommandOutput(exitCode: process.terminationStatus, standardOutput: output, standardError: error)
}

/// Checks for claims a review could only state, not prove.
///
/// Nothing here changes a real setting. The Touch ID commands run against a
/// copy in a temporary folder, as the current user, never against `/etc`.
@Suite struct UnverifiedClaimsTests {
    @Test func `the documented counts of settings are the real counts`() {
        let all = Catalog.tweaks(home: home)
        #expect(all.count == 412)
        #expect(all.count { $0.appliesInstantly } == 298)
        #expect(all.count { $0.requiresAdministrator } == 57)
    }

    /// The real commands, the real `sed` and `grep`, and Apple's own template
    /// from this Mac, with only the path swapped for a temporary one.
    @Test func `touch id for sudo turns on, reads back, and turns off against Apple's template`() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "mackit-pam-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let real = "/etc/pam.d/sudo_local"
        let target = folder.appending(path: "sudo_local").path(percentEncoded: false)
        let template = (try? String(contentsOfFile: real + ".template", encoding: .utf8)) ?? """
        # sudo_local: local config file which survives system update and is included for sudo
        # uncomment following line to enable Touch ID for sudo
        #auth       sufficient     pam_tid.so

        """
        try template.write(toFile: target + ".template", atomically: true, encoding: .utf8)

        let tweak = try #require(Catalog.tweaks(home: home).first { $0.id == "security.touch-id-sudo" })
        guard case .privileged(let setting) = tweak.mechanism else {
            Issue.record("Touch ID for sudo is no longer a privileged setting")
            return
        }

        func apply(_ option: String) throws {
            for command in try #require(setting.commands[option]) {
                let result = try run(command.executable, command.arguments.map { $0.replacing(real, with: target) })
                #expect(result.exitCode == 0, "\(option): \(result.standardError)")
            }
        }
        func state() throws -> String? {
            let probe = setting.probe.command
            return setting.probe.option(for: try run(probe.executable, probe.arguments.map { $0.replacing(real, with: target) }))
        }
        func text() throws -> String { try String(contentsOfFile: target, encoding: .utf8) }
        func mode() throws -> Int {
            (try FileManager.default.attributesOfItem(atPath: target)[.posixPermissions] as? Int) ?? -1
        }

        // No file yet: reads as off.
        #expect(try state() == "off")

        // On: the file is made from the template with exactly one live line.
        try apply("on")
        #expect(try state() == "on")
        let enabled = try text()
        #expect(enabled.split(separator: "\n").filter { $0.hasPrefix("auth") && $0.contains("pam_tid.so") }.count == 1)
        #expect(enabled.hasPrefix("# sudo_local"), "Apple's comments are kept")
        #expect(try mode() == 0o444)

        // On again changes nothing.
        try apply("on")
        #expect(try text() == enabled)
        #expect(try mode() == 0o444)

        // Off: the line is commented out again, leaving the template's text.
        try apply("off")
        #expect(try state() == "off")
        #expect(try text() == template)
        #expect(try mode() == 0o444)

        // And back on from a file that already exists.
        try apply("on")
        #expect(try state() == "on")
        #expect(try text() == enabled)
    }
}

/// Reads this Mac's real power settings. Nothing is changed. Off unless
/// `MACKIT_LIVE=1`, like the other checks that depend on the machine.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MACKIT_LIVE"] == "1"))
struct LivePowerTests {
    @Test func `every power key MacKit writes is one this Mac's pmset knows`() throws {
        let known = try run("/usr/bin/pmset", ["-g", "custom"]).standardOutput
            + (try run("/usr/bin/pmset", ["-g", "cap"])).standardOutput
            + (try run("/bin/sh", ["-c", "/usr/bin/man pmset 2>/dev/null | /usr/bin/col -b"])).standardOutput
            // Some keys, such as `disablesleep`, are undocumented but are
            // named in the tool itself.
            + (try run("/usr/bin/strings", ["/usr/bin/pmset"])).standardOutput
        #expect(!known.isEmpty)

        var keys: Set<String> = []
        for tweak in Catalog.tweaks(home: home) {
            guard case .privileged(let setting) = tweak.mechanism else { continue }
            for command in setting.commands.values.joined() where command.executable == "/usr/bin/pmset" {
                // `pmset -a displaysleep 10`: a scope flag, then key and value.
                #expect(command.arguments.count == 3, "\(tweak.id): \(command.arguments)")
                #expect(["-a", "-b", "-c"].contains(command.arguments.first ?? ""), "\(tweak.id)")
                if command.arguments.count == 3 { keys.insert(command.arguments[1]) }
            }
        }
        #expect(!keys.isEmpty)
        for key in keys.sorted() {
            #expect(known.contains(key), "pmset on this Mac doesn't mention \(key)")
        }
        print("PMSET KEYS \(keys.sorted().joined(separator: " "))")
    }

    @Test func `this Mac's real power settings are all recognised`() async throws {
        let realHome = FileManager.default.homeDirectoryForCurrentUser
        let access = SystemAccess(
            preferences: SystemPreferenceStore(), commands: AllowlistedCommandRunner(),
            privileged: InMemorySystem(), fileFlags: SystemFileFlagStore(), homeDirectory: realHome
        )
        let tweaks = Catalog.tweaks(home: realHome).filter { $0.category == .power }
        let states = await TweakEngine(system: access).states(of: tweaks)
        for tweak in tweaks {
            let state = states[tweak.id] ?? .unknown
            print("POWER \(tweak.id.padding(toLength: 30, withPad: " ", startingAt: 0)) \(state)")
            // A value read as "custom" means MacKit offers no option for
            // what this Mac is really set to.
            if case .custom(let raw) = state { Issue.record("\(tweak.id) reads as custom: \(raw)") }
        }
    }
}
