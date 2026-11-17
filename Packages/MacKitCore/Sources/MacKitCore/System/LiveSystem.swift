import Foundation

/// Preferences backed by CFPreferences, the same store `defaults` writes to.
///
/// Writing through the API instead of spawning `defaults` keeps values typed
/// and avoids a process launch per key.
public struct SystemPreferenceStore: PreferenceStoring {
    public init() {}

    public func value(for key: String, path: [String], in domain: PreferenceDomain) -> PreferenceValue? {
        let topKey = path.first ?? key
        let raw: CFPropertyList?
        switch domain.location {
        case .preferences(let name, let user, let host):
            if domain.requiresAdministrator {
                // Another process (root's `defaults`) writes these, so ask for
                // a fresh copy rather than this process's cached one.
                CFPreferencesSynchronize(name, user, host)
            }
            raw = CFPreferencesCopyValue(topKey as CFString, name, user, host)
        case .file(let url):
            raw = (NSDictionary(contentsOf: url)?[topKey]).map { $0 as CFPropertyList }
        }
        guard let raw else { return nil }
        guard !path.isEmpty else { return PreferenceValue(propertyList: raw) }

        var current: Any = raw
        for step in path.dropFirst() {
            guard let dictionary = current as? NSDictionary, let next = dictionary[step] else { return nil }
            current = next
        }
        guard let dictionary = current as? NSDictionary, let leaf = dictionary[key] else { return nil }
        return PreferenceValue(propertyList: leaf as CFPropertyList)
    }

    public func set(_ value: PreferenceValue?, for key: String, path: [String], in domain: PreferenceDomain) throws(SystemError) {
        // Shared preference files are written as root, through the
        // administrator prompt, never from here.
        guard !domain.requiresAdministrator, case .preferences(let name, let user, let host) = domain.location else {
            throw .preferenceWriteFailed(domain: domain.commandLineName, key: key)
        }
        if let topKey = path.first {
            let existing = (CFPreferencesCopyValue(topKey as CFString, name, user, host) as? [String: Any]) ?? [:]
            let updated = Self.updating(existing, along: path.dropFirst(), key: key, to: value)
            CFPreferencesSetValue(topKey as CFString, updated.isEmpty ? nil : updated as CFDictionary, name, user, host)
        } else {
            CFPreferencesSetValue(key as CFString, value?.propertyList, name, user, host)
        }
        guard CFPreferencesSynchronize(name, user, host) else {
            throw .preferenceWriteFailed(domain: domain.commandLineName, key: key)
        }
    }

    /// Updates a single leaf inside a nested preference dictionary without
    /// disturbing any sibling keys.
    static func updating(_ dictionary: [String: Any], along steps: ArraySlice<String>, key: String, to value: PreferenceValue?) -> [String: Any] {
        var copy = dictionary
        if let head = steps.first {
            let child = (copy[head] as? [String: Any]) ?? [:]
            let next = updating(child, along: steps.dropFirst(), key: key, to: value)
            if next.isEmpty { copy.removeValue(forKey: head) } else { copy[head] = next }
        } else if let value {
            copy[key] = value.propertyList
        } else {
            copy.removeValue(forKey: key)
        }
        return copy
    }
}

extension PreferenceDomain {
    fileprivate enum Location {
        case preferences(name: CFString, user: CFString, host: CFString)
        case file(URL)
    }

    fileprivate var location: Location {
        switch self {
        case .global:
            return .preferences(name: kCFPreferencesAnyApplication, user: kCFPreferencesCurrentUser, host: kCFPreferencesAnyHost)
        case .app(let identifier):
            return .preferences(name: identifier as CFString, user: kCFPreferencesCurrentUser, host: kCFPreferencesAnyHost)
        case .currentHostGlobal:
            return .preferences(name: kCFPreferencesAnyApplication, user: kCFPreferencesCurrentUser, host: kCFPreferencesCurrentHost)
        case .currentHost(let identifier):
            return .preferences(name: identifier as CFString, user: kCFPreferencesCurrentUser, host: kCFPreferencesCurrentHost)
        case .system(let path):
            // Files directly inside /Library/Preferences are served by the
            // preferences system. Anything else is read as a plain file.
            if !isDirectSystemFile {
                let prefix = "/Library/Preferences/"
                return .preferences(name: path.dropFirst(prefix.count) as CFString, user: kCFPreferencesAnyUser, host: kCFPreferencesCurrentHost)
            }
            return .file(URL(filePath: path + ".plist"))
        }
    }
}

extension PreferenceValue {
    init?(propertyList: CFPropertyList) {
        let typeID = CFGetTypeID(propertyList)
        if typeID == CFBooleanGetTypeID(), let value = propertyList as? Bool {
            self = .bool(value)
        } else if typeID == CFNumberGetTypeID(), let number = propertyList as? NSNumber {
            self = CFNumberIsFloatType(number) ? .double(number.doubleValue) : .int(number.intValue)
        } else if typeID == CFStringGetTypeID(), let value = propertyList as? String {
            self = .string(value)
        } else {
            return nil
        }
    }

    var propertyList: CFPropertyList {
        switch self {
        case .bool(let value): value as CFBoolean
        case .int(let value): value as CFNumber
        case .double(let value): value as CFNumber
        case .string(let value): value as CFString
        }
    }
}

/// Runs commands with `Process`, restricted to a fixed list of executables.
public struct AllowlistedCommandRunner: CommandRunning {
    /// The only programs MacKit will ever launch as the current user.
    public static let allowedExecutables: Set<String> = [
        "/usr/bin/killall",
        "/usr/sbin/system_profiler",
        // Read-only checks of system-wide settings.
        "/usr/sbin/nvram",
        "/usr/libexec/ApplicationFirewall/socketfilterfw",
        "/usr/bin/pmset",
        "/usr/sbin/ioreg",
        "/bin/launchctl",
        "/usr/sbin/cupsctl",
        "/usr/bin/AssetCacheManagerUtil",
        "/usr/sbin/sysadminctl",
        "/usr/bin/mdutil",
        "/usr/sbin/sysctl",
        "/usr/bin/grep",
        "/usr/bin/defaults",
        "/usr/sbin/scutil",
    ]

    public init() {}

    public func run(_ command: Command) async throws(SystemError) -> CommandOutput {
        guard Self.allowedExecutables.contains(command.executable) else {
            throw .commandNotAllowed(command.executable)
        }

        let process = Process()
        process.executableURL = URL(filePath: command.executable)
        process.arguments = command.arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = FileHandle.nullDevice

        let exitCode: Int32
        do {
            exitCode = try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { finished in
                    continuation.resume(returning: finished.terminationStatus)
                }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } catch {
            throw .launchFailed(command: command.shellText, message: error.localizedDescription)
        }

        // The commands MacKit runs print a line or two, well under the pipe
        // buffer, so reading after exit cannot deadlock.
        let output = String(decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let errorOutput = String(decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return CommandOutput(exitCode: exitCode, standardOutput: output, standardError: errorOutput)
    }
}

public struct SystemFileFlagStore: FileFlagStoring {
    public init() {}

    public func isHidden(_ url: URL) throws(SystemError) -> Bool {
        do {
            return try url.resourceValues(forKeys: [.isHiddenKey]).isHidden ?? false
        } catch {
            throw .fileFlagFailed(path: url.path(percentEncoded: false), message: error.localizedDescription)
        }
    }

    public func setHidden(_ hidden: Bool, _ url: URL) throws(SystemError) {
        var values = URLResourceValues()
        values.isHidden = hidden
        var target = url
        do {
            try target.setResourceValues(values)
        } catch {
            throw .fileFlagFailed(path: url.path(percentEncoded: false), message: error.localizedDescription)
        }
    }
}

/// Whether this app has Full Disk Access.
///
/// There is no API for the question, so this tries to open a file that
/// macOS only shows to apps that have it. Trying never prompts the user.
public func hasFullDiskAccess(home: URL) -> Bool {
    let database = home.appending(path: "Library/Application Support/com.apple.TCC/TCC.db")
    guard let handle = try? FileHandle(forReadingFrom: database) else { return false }
    try? handle.close()
    return true
}
