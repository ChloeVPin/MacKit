import Foundation
import Synchronization

/// A complete fake of the machine, for tests and for running the app against
/// sample data without touching real settings.
///
/// It knows the catalog it was created with, so system-wide settings behave
/// like the real thing: running an option's commands as administrator makes
/// that setting's read-only check report the option afterwards.
public final class InMemorySystem: PreferenceStoring, CommandRunning, PrivilegedRunning, FileFlagStoring, Sendable {
    private struct Key: Hashable {
        var domain: PreferenceDomain
        var key: String
    }

    private struct Storage: @unchecked Sendable {
        var preferences: [Key: PreferenceValue] = [:]
        /// Nested plist dictionaries keyed by their top-level preference key,
        /// updated with the same `SystemPreferenceStore.updating` logic as
        /// real `CFPreferences` dictionaries.
        var dictionaries: [Key: [String: Any]] = [:]
        var hiddenPaths: Set<String> = []
        /// The option each system-wide setting is in. Absent means stock.
        var privilegedOptions: [Tweak.ID: TweakOption.ID] = [:]
        var commandsRun: [Command] = []
        var privilegedBatches: [[Command]] = []
        var failingKeys: Set<String> = []
        var failingPrivilegedCommands: Set<Command> = []
        var authorizationError: SystemError?
    }

    private let storage = Mutex(Storage())
    private let settings: [(tweak: Tweak, setting: PrivilegedSetting)]

    public init(tweaks: [Tweak] = Catalog.tweaks(home: URL(filePath: "/Users/sample"))) {
        settings = tweaks.compactMap { tweak in
            if case .privileged(let setting) = tweak.mechanism { (tweak, setting) } else { nil }
        }
    }

    /// A `SystemAccess` in which every dependency is this fake.
    public func access(home: URL = URL(filePath: "/Users/sample")) -> SystemAccess {
        let library = home.appending(path: "Library", directoryHint: .isDirectory).path(percentEncoded: false)
        storage.withLock { _ = $0.hiddenPaths.insert(library) }
        return SystemAccess(preferences: self, commands: self, privileged: self, fileFlags: self, homeDirectory: home)
    }

    // MARK: Test controls

    /// Every command run as the current user, in order.
    public var commandsRun: [Command] { storage.withLock { $0.commandsRun } }
    /// Each administrator authorization, with the commands it covered.
    public var privilegedBatches: [[Command]] { storage.withLock { $0.privilegedBatches } }

    /// Makes writes to the given key fail.
    public func failWrites(to key: String) {
        storage.withLock { _ = $0.failingKeys.insert(key) }
    }

    /// Makes the next administrator authorization fail with `error`.
    public func failAuthorization(with error: SystemError) {
        storage.withLock { $0.authorizationError = error }
    }

    /// Makes a specific root command fail when an administrator batch runs it.
    public func failPrivilegedCommand(_ command: Command) {
        storage.withLock { _ = $0.failingPrivilegedCommands.insert(command) }
    }

    /// Reads or seeds a raw top-level dictionary preference, such as Finder's
    /// `DesktopViewSettings`, for testing nested sibling preservation.
    public func dictionary(for topKey: String, in domain: PreferenceDomain) -> [String: Any]? {
        storage.withLock { $0.dictionaries[Key(domain: domain, key: topKey)] }
    }

    public func setDictionary(_ dictionary: [String: Any]?, for topKey: String, in domain: PreferenceDomain) {
        storage.withLock { $0.dictionaries[Key(domain: domain, key: topKey)] = dictionary }
    }

    // MARK: PreferenceStoring

    public func value(for key: String, path: [String], in domain: PreferenceDomain) -> PreferenceValue? {
        storage.withLock { storage in
            guard let topKey = path.first else {
                return storage.preferences[Key(domain: domain, key: key)]
            }
            guard var current: Any = storage.dictionaries[Key(domain: domain, key: topKey)] else { return nil }
            for step in path.dropFirst() {
                guard let dict = current as? [String: Any], let next = dict[step] else { return nil }
                current = next
            }
            guard let dict = current as? [String: Any], let leaf = dict[key] else { return nil }
            return PreferenceValue(propertyList: leaf as CFPropertyList)
        }
    }

    public func set(_ value: PreferenceValue?, for key: String, path: [String], in domain: PreferenceDomain) throws(SystemError) {
        let failed = storage.withLock { storage in
            if storage.failingKeys.contains(key) || domain.requiresAdministrator { return true }
            if let topKey = path.first {
                let top = Key(domain: domain, key: topKey)
                let existing = storage.dictionaries[top] ?? [:]
                let updated = SystemPreferenceStore.updating(existing, along: path.dropFirst(), key: key, to: value)
                storage.dictionaries[top] = updated.isEmpty ? nil : updated
            } else {
                storage.preferences[Key(domain: domain, key: key)] = value
            }
            return false
        }
        if failed { throw .preferenceWriteFailed(domain: domain.commandLineName, key: key) }
    }

    // MARK: FileFlagStoring

    public func isHidden(_ url: URL) throws(SystemError) -> Bool {
        storage.withLock { $0.hiddenPaths.contains(url.path(percentEncoded: false)) }
    }

    public func setHidden(_ hidden: Bool, _ url: URL) throws(SystemError) {
        let path = url.path(percentEncoded: false)
        storage.withLock { storage in
            if hidden { storage.hiddenPaths.insert(path) } else { storage.hiddenPaths.remove(path) }
        }
    }

    // MARK: CommandRunning

    public func run(_ command: Command) async throws(SystemError) -> CommandOutput {
        storage.withLock { storage in
            storage.commandsRun.append(command)

            if command.executable == "/usr/sbin/system_profiler" {
                let report = #"{"SPHardwareDataType":[{"machine_name":"MacBook Air","chip_type":"Apple M2","physical_memory":"16 GB"}]}"#
                return CommandOutput(exitCode: 0, standardOutput: report, standardError: "")
            }
            if command.executable == "/usr/sbin/ioreg", command.arguments == ["-rd1", "-c", "AppleSmartBattery"] {
                return CommandOutput(exitCode: 0, standardOutput: "  \"BatteryInstalled\" = Yes\n", standardError: "")
            }

            // Several settings can share one read command (every power
            // setting reads the same report), so answer with all of them.
            let readers = settings.filter { $0.setting.probe.command == command }
            guard !readers.isEmpty else { return CommandOutput(exitCode: 0, standardOutput: "", standardError: "") }

            var lines: [String] = []
            for (tweak, setting) in readers {
                // A setting with no default, like the computer's name, still
                // holds something on a real Mac.
                let option = storage.privilegedOptions[tweak.id]
                    ?? (tweak.hasDefault ? tweak.stockOptionID : tweak.entryID(for: .string("MacBook Air")))
                if let match = setting.probe.matches.first(where: { $0.option == option }) {
                    lines.append(match.example)
                } else if let capture = setting.probe.capture, let value = tweak.entry(option)?.displayText {
                    lines.append(capture.example.replacing(PrivilegedSetting.valuePlaceholder, with: value))
                } else if readers.count == 1 {
                    // This state is the one the tool reports by failing.
                    return CommandOutput(exitCode: 1, standardOutput: "", standardError: "not set\n")
                }
            }
            return CommandOutput(exitCode: 0, standardOutput: lines.joined(separator: "\n") + "\n", standardError: "")
        }
    }

    // MARK: PrivilegedRunning

    public func runAsAdministrator(_ commands: [Command]) async throws(SystemError) {
        let outcomes = try await runAsAdministrator([PrivilegedGroup(id: "_batch", commands: commands)])
        if case .failure(let error)? = outcomes["_batch"] { throw error }
    }

    public func runAsAdministrator(_ groups: [PrivilegedGroup]) async throws(SystemError) -> [Tweak.ID: Result<Void, SystemError>] {
        let result = storage.withLock { storage -> Result<[Tweak.ID: Result<Void, SystemError>], SystemError> in
            if let error = storage.authorizationError {
                storage.authorizationError = nil
                return .failure(error)
            }
            let allCommands = groups.flatMap(\.commands)
            storage.privilegedBatches.append(allCommands)

            var outcomes: [Tweak.ID: Result<Void, SystemError>] = [:]
            for group in groups {
                if let failed = group.commands.first(where: { storage.failingPrivilegedCommands.contains($0) && !$0.toleratesFailure }) {
                    outcomes[group.id] = .failure(.commandFailed(command: failed.shellText, exitCode: 1, message: "Simulated root failure"))
                    continue
                }
                for command in group.commands where command.executable == "/usr/bin/defaults" {
                    Self.applyDefaults(command.arguments, to: &storage)
                }
                for (tweak, setting) in settings {
                    var finished = setting.commands.compactMap { option, wanted -> (TweakOption.ID, Int)? in
                        guard !wanted.isEmpty, let last = wanted.compactMap({ group.commands.lastIndex(of: $0) }).max(),
                              wanted.allSatisfy(group.commands.contains) else { return nil }
                        return (option, last)
                    }
                    if let template = setting.valueCommands.first,
                       let slot = template.arguments.firstIndex(of: PrivilegedSetting.valuePlaceholder),
                       let index = group.commands.lastIndex(where: { command in
                           command.executable == template.executable && command.arguments.count == template.arguments.count
                               && zip(command.arguments, template.arguments).enumerated().allSatisfy { $0.offset == slot || $0.element.0 == $0.element.1 }
                       }) {
                        finished.append((tweak.entryID(for: .string(group.commands[index].arguments[slot])), index))
                    }
                    if let winner = finished.max(by: { $0.1 < $1.1 }) {
                        storage.privilegedOptions[tweak.id] = winner.0
                    }
                }
                outcomes[group.id] = .success(())
            }
            return .success(outcomes)
        }
        return try result.get()
    }

    /// Carries out `defaults write <path> <key> -<type> <value>` and
    /// `defaults delete <path> <key>` against the fake preference store.
    private static func applyDefaults(_ arguments: [String], to storage: inout Storage) {
        guard arguments.count >= 3 else { return }
        let key = Key(domain: .system(arguments[1]), key: arguments[2])
        switch arguments[0] {
        case "delete":
            storage.preferences[key] = nil
        case "write" where arguments.count == 5:
            let text = arguments[4]
            switch arguments[3] {
            case "-bool": storage.preferences[key] = .bool(text == "true")
            case "-int": storage.preferences[key] = Int(text).map(PreferenceValue.int)
            case "-float": storage.preferences[key] = Double(text).map(PreferenceValue.double)
            case "-string": storage.preferences[key] = .string(text)
            default: break
            }
        default:
            break
        }
    }
}
