import Foundation

/// A single write MacKit will make to the system.
public enum Operation: Hashable, Sendable {
    /// Writes a preference key, or removes it when `value` is `nil`.
    case writePreference(domain: PreferenceDomain, path: [String] = [], key: String, value: PreferenceValue?)
    case setLibraryHidden(Bool)
    /// Runs a command as root.
    case privileged(Command)

    /// The operation written as the Terminal command that does the same
    /// thing. Shown to the user before anything runs.
    public var commandText: String {
        switch self {
        case .writePreference(let domain, let path, let key, let value) where !path.isEmpty:
            let entry = ":" + (path + [key]).joined(separator: ":")
            let action = value.map { "Set \(entry) \($0.displayText)" } ?? "Delete \(entry)"
            let plist = Self.plistPath(for: domain)
            let prefix = domain.requiresAdministrator ? "sudo " : ""
            return "\(prefix)/usr/libexec/PlistBuddy -c \(Command.quote(action)) \(plist)"
        case .writePreference(let domain, _, _, _):
            let command = Self.defaultsCommand(self)!
            let text = command.shellText.replacing("/usr/bin/defaults", with: "defaults", maxReplacements: 1)
            return domain.requiresAdministrator ? "sudo " + text : text
        case .setLibraryHidden(let hidden):
            return "chflags \(hidden ? "hidden" : "nohidden") ~/Library"
        case .privileged(let command):
            return "sudo " + command.shellText
        }
    }

    public var isPrivileged: Bool {
        switch self {
        case .privileged: true
        case .writePreference(let domain, _, _, _): domain.requiresAdministrator
        case .setLibraryHidden: false
        }
    }

    /// The command to run as root for this operation, if it needs root.
    public var privilegedCommand: Command? {
        switch self {
        case .privileged(let command): command
        case .writePreference(let domain, _, _, _) where domain.requiresAdministrator: Self.defaultsCommand(self)
        case .writePreference, .setLibraryHidden: nil
        }
    }

    private static func defaultsCommand(_ operation: Operation) -> Command? {
        guard case .writePreference(let domain, let path, let key, let value) = operation, path.isEmpty else { return nil }
        if let value {
            return Command(executable: "/usr/bin/defaults", arguments: domain.defaultsArguments("write") + [key] + value.defaultsArguments)
        }
        // Removing a key that isn't there fails, and that's fine.
        return Command(executable: "/usr/bin/defaults", arguments: domain.defaultsArguments("delete") + [key], toleratesFailure: true)
    }

    private static func plistPath(for domain: PreferenceDomain) -> String {
        switch domain {
        case .global: "~/Library/Preferences/.GlobalPreferences.plist"
        case .app(let identifier): "~/Library/Preferences/\(Command.quote(identifier + ".plist"))"
        case .currentHostGlobal: "~/Library/Preferences/ByHost/.GlobalPreferences.*.plist"
        case .currentHost(let identifier): "~/Library/Preferences/ByHost/\(Command.quote(identifier)).*.plist"
        case .system(let path): Command.quote(path + ".plist")
        }
    }
}

/// What a planned change is moving a tweak to.
public enum ChangeTarget: Hashable, Sendable {
    /// One of the tweak's options.
    case option(TweakOption.ID)
    /// The exact state recorded before an earlier change.
    case restore(Snapshot)
}

/// One tweak's worth of operations.
public struct PlannedChange: Identifiable, Hashable, Sendable {
    public let tweak: Tweak
    public let target: ChangeTarget
    public let operations: [Operation]

    public var id: Tweak.ID { tweak.id }
    public var isPrivileged: Bool { operations.contains(where: \.isPrivileged) }
}

/// The complete, ordered list of what will happen when the user applies.
///
/// Building a plan has no side effects. The same plan that is shown in the
/// review sheet is the one that runs.
public struct ChangePlan: Hashable, Sendable {
    public let changes: [PlannedChange]

    public init(changes: [PlannedChange]) {
        self.changes = changes
    }

    public var isEmpty: Bool { changes.isEmpty }

    /// System processes that are restarted after the changes are written.
    public var restarts: [RestartTarget] {
        RestartTarget.allCases.filter { target in
            changes.contains { $0.tweak.effect == .restarts(target) }
        }
    }

    public var privilegedChangeCount: Int {
        changes.count(where: \.isPrivileged)
    }

    public var needsLogout: Bool { changes.contains { $0.tweak.effect == .logout } }
    public var needsAppRelaunch: Bool { changes.contains { $0.tweak.effect == .appRelaunch } }
}

/// How one planned change ended.
public enum ChangeOutcome: Hashable, Sendable {
    case applied
    case failed(SystemError)

    public var isApplied: Bool { self == .applied }
}

public struct ChangeResult: Identifiable, Hashable, Sendable {
    public let change: PlannedChange
    /// The state of the tweak before the change. Present whenever the change
    /// was applied, so it can be reverted.
    public let snapshot: Snapshot?
    public let outcome: ChangeOutcome

    public var id: Tweak.ID { change.id }
}

/// Progress reported while a plan is being applied.
public enum ChangeProgress: Hashable, Sendable {
    case running
    case finished(ChangeOutcome)
}
