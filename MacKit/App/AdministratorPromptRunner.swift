import Foundation
import MacKitCore

/// Runs commands as root by asking macOS for an administrator password.
///
/// This uses the system's own authorization prompt, so MacKit never sees the
/// password. It's the approach that works for an app without a Developer ID
/// signature. A signed build can replace this with an `SMAppService` helper
/// without touching anything else: the engine only knows `PrivilegedRunning`.
nonisolated struct AdministratorPromptRunner: PrivilegedRunning {
    func runAsAdministrator(_ commands: [Command]) async throws(SystemError) {
        guard !commands.isEmpty else { return }
        let outcomes = try await runAsAdministrator([PrivilegedGroup(id: "_batch", commands: commands)])
        if case .failure(let error)? = outcomes["_batch"] {
            throw error
        }
    }

    func runAsAdministrator(_ groups: [PrivilegedGroup]) async throws(SystemError) -> [Tweak.ID: Result<Void, SystemError>] {
        let active = groups.filter { !$0.commands.isEmpty }
        guard !active.isEmpty else {
            return Dictionary(uniqueKeysWithValues: groups.map { ($0.id, .success(())) })
        }

        // Every word is shell-quoted by `Command.shellText`, and each group
        // runs in its own subshell so one failing change never hides earlier
        // root changes or skips unrelated ones. The whole script is escaped
        // once more for the AppleScript string literal.
        let script = PrivilegedBatchScript.build(for: groups)
        let literal = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let count = active.count
        let prompt = "MacKit needs an administrator password to apply \(count == 1 ? "this change" : "these changes")."
        let source = "do shell script \"\(literal)\" with prompt \"\(prompt)\" with administrator privileges"

        // NSAppleScript must run on the main thread. The system prompt is
        // modal, so nothing else in the app is waiting on it.
        let result: Result<String, SystemError> = await MainActor.run {
            var errorInfo: NSDictionary?
            guard let appleScript = NSAppleScript(source: source) else {
                return .failure(.authorizationFailed("MacKit couldn't prepare the administrator request."))
            }
            let descriptor = appleScript.executeAndReturnError(&errorInfo)
            if let errorInfo {
                let code = errorInfo[NSAppleScript.errorNumber] as? Int
                if code == -128 {
                    return .failure(.authorizationCancelled)
                }
                let message = errorInfo[NSAppleScript.errorMessage] as? String
                return .failure(.authorizationFailed(message ?? "The administrator request failed."))
            }
            return .success(descriptor.stringValue ?? "")
        }
        let output = try result.get()
        return PrivilegedBatchScript.parse(output, for: groups)
    }
}
