import Foundation

/// Reads and writes preference keys.
public protocol PreferenceStoring: Sendable {
    func value(for key: String, path: [String], in domain: PreferenceDomain) -> PreferenceValue?
    /// Writes `value`, or removes the key when `value` is `nil`.
    func set(_ value: PreferenceValue?, for key: String, path: [String], in domain: PreferenceDomain) throws(SystemError)
}

extension PreferenceStoring {
    public func value(for key: String, in domain: PreferenceDomain) -> PreferenceValue? {
        value(for: key, path: [], in: domain)
    }

    public func set(_ value: PreferenceValue?, for key: String, in domain: PreferenceDomain) throws(SystemError) {
        try set(value, for: key, path: [], in: domain)
    }
}

/// Runs a command as the current user.
public protocol CommandRunning: Sendable {
    func run(_ command: Command) async throws(SystemError) -> CommandOutput
}

/// One tweak's root commands within an administrator batch.
public struct PrivilegedGroup: Sendable, Hashable {
    public let id: Tweak.ID
    public let commands: [Command]

    public init(id: Tweak.ID, commands: [Command]) {
        self.id = id
        self.commands = commands
    }
}

/// Builds and parses a POSIX shell script that runs several privileged command
/// groups under a single authentication prompt while reporting each group's
/// outcome independently.
public enum PrivilegedBatchScript {
    public static func build(for groups: [PrivilegedGroup]) -> String {
        var clauses: [String] = []
        for (index, group) in groups.enumerated() where !group.commands.isEmpty {
            let chain = group.commands
                .map { $0.toleratesFailure ? "{ \($0.shellText) || true; }" : $0.shellText }
                .joined(separator: " && ")
            clauses.append("""
            __mk_err=$( ( \(chain) ) 2>&1 >/dev/null ); __mk_rc=$?; \
            if [ $__mk_rc -eq 0 ]; then printf '__MACKIT_OK__:%d\\n' \(index); \
            else printf '__MACKIT_ERR__:%d:%d:%s\\n' \(index) "$__mk_rc" "$(/usr/bin/printf '%s' "$__mk_err" | /usr/bin/tr '\\r\\n' '  ')"; fi
            """)
        }
        clauses.append("exit 0")
        return clauses.joined(separator: "; ")
    }

    public static func parse(_ output: String, for groups: [PrivilegedGroup]) -> [Tweak.ID: Result<Void, SystemError>] {
        var outcomes: [Int: Result<Void, SystemError>] = [:]
        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            if line.hasPrefix("__MACKIT_OK__:") {
                if let index = Int(line.dropFirst("__MACKIT_OK__:".count)) {
                    outcomes[index] = .success(())
                }
            } else if line.hasPrefix("__MACKIT_ERR__:") {
                let rest = line.dropFirst("__MACKIT_ERR__:".count)
                let parts = rest.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
                if parts.count >= 2, let index = Int(parts[0]), let code = Int32(parts[1]), groups.indices.contains(index) {
                    let message = parts.count == 3 ? String(parts[2]).trimmingCharacters(in: .whitespaces) : ""
                    let text = groups[index].commands.map(\.shellText).joined(separator: " && ")
                    outcomes[index] = .failure(.commandFailed(command: text, exitCode: code, message: message))
                }
            }
        }
        var mapped: [Tweak.ID: Result<Void, SystemError>] = [:]
        for (index, group) in groups.enumerated() {
            if group.commands.isEmpty {
                mapped[group.id] = .success(())
            } else {
                mapped[group.id] = outcomes[index] ?? .failure(.authorizationFailed("The administrator command didn't finish."))
            }
        }
        return mapped
    }
}

/// Runs commands as root, after the user authenticates.
///
/// All commands are passed in one call so the user is asked for a password
/// once per batch, not once per change.
public protocol PrivilegedRunning: Sendable {
    func runAsAdministrator(_ commands: [Command]) async throws(SystemError)
    func runAsAdministrator(_ groups: [PrivilegedGroup]) async throws(SystemError) -> [Tweak.ID: Result<Void, SystemError>]
}

extension PrivilegedRunning {
    public func runAsAdministrator(_ groups: [PrivilegedGroup]) async throws(SystemError) -> [Tweak.ID: Result<Void, SystemError>] {
        try await runAsAdministrator(groups.flatMap(\.commands))
        return Dictionary(uniqueKeysWithValues: groups.map { ($0.id, .success(())) })
    }
}

/// Reads and writes the hidden flag on a file or folder.
public protocol FileFlagStoring: Sendable {
    func isHidden(_ url: URL) throws(SystemError) -> Bool
    func setHidden(_ hidden: Bool, _ url: URL) throws(SystemError)
}

public struct CommandOutput: Sendable, Hashable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String

    public init(exitCode: Int32, standardOutput: String, standardError: String) {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public enum SystemError: Error, Hashable, Sendable {
    case commandNotAllowed(String)
    case commandFailed(command: String, exitCode: Int32, message: String)
    case launchFailed(command: String, message: String)
    case preferenceWriteFailed(domain: String, key: String)
    case fileFlagFailed(path: String, message: String)
    /// The user dismissed the administrator password prompt.
    case authorizationCancelled
    case authorizationFailed(String)

    /// A sentence suitable for showing next to a failed change.
    public var explanation: String {
        switch self {
        case .commandNotAllowed(let path):
            "MacKit isn't allowed to run \(path)."
        case .commandFailed(let command, let exitCode, let message):
            message.isEmpty ? "\(command) exited with code \(exitCode)." : message
        case .launchFailed(let command, let message):
            "Couldn't start \(command): \(message)"
        case .preferenceWriteFailed(let domain, let key):
            "macOS refused the write to \(domain) \(key)."
        case .fileFlagFailed(let path, let message):
            "Couldn't change \(path): \(message)"
        case .authorizationCancelled:
            "The administrator prompt was cancelled."
        case .authorizationFailed(let message):
            message
        }
    }
}

/// Everything the engine needs from the machine, gathered so tests can swap
/// the whole system for an in-memory fake.
public struct SystemAccess: Sendable {
    public var preferences: any PreferenceStoring
    public var commands: any CommandRunning
    public var privileged: any PrivilegedRunning
    public var fileFlags: any FileFlagStoring
    public var homeDirectory: URL
    /// Whether macOS lets this app into other apps' protected preferences.
    /// Granted by the user in Privacy & Security settings.
    public var hasFullDiskAccess: @Sendable () -> Bool
    /// Tells macOS that a saved setting changed, so what's already running
    /// picks it up.
    public var announce: @Sendable (LiveSignal) -> Void

    public init(
        preferences: any PreferenceStoring,
        commands: any CommandRunning,
        privileged: any PrivilegedRunning,
        fileFlags: any FileFlagStoring,
        homeDirectory: URL,
        hasFullDiskAccess: @escaping @Sendable () -> Bool = { true },
        announce: @escaping @Sendable (LiveSignal) -> Void = { _ in }
    ) {
        self.preferences = preferences
        self.commands = commands
        self.privileged = privileged
        self.fileFlags = fileFlags
        self.homeDirectory = homeDirectory
        self.announce = announce
        self.hasFullDiskAccess = hasFullDiskAccess
    }
}
