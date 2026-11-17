import Foundation

/// Reads the state of tweaks, plans changes, and applies them.
public struct TweakEngine: Sendable {
    public let system: SystemAccess

    public init(system: SystemAccess) {
        self.system = system
    }

    private var libraryURL: URL {
        system.homeDirectory.appending(path: "Library", directoryHint: .isDirectory)
    }

    // MARK: Reading

    private static let batteryProbe = Command("/usr/sbin/ioreg", "-rd1", "-c", "AppleSmartBattery")

    private static func hasBattery(in output: CommandOutput?) -> Bool {
        guard let text = output?.standardOutput else { return false }
        return text.contains("BatteryInstalled") && !text.contains(#""BatteryInstalled" = No"#)
    }

    @concurrent
    public func states(of tweaks: [Tweak]) async -> [Tweak.ID: TweakState] {
        let hasFullDiskAccess = system.hasFullDiskAccess()

        // Several settings read the same report (every power setting reads
        // `pmset -g custom`), so run each distinct read command at most once,
        // bounded to keep process launches polite.
        var uniqueCommands: [Command] = []
        var seenCommands: Set<Command> = []
        if tweaks.contains(where: \.requiresBattery), seenCommands.insert(Self.batteryProbe).inserted {
            uniqueCommands.append(Self.batteryProbe)
        }
        for tweak in tweaks {
            if tweak.requiresFullDiskAccess, !hasFullDiskAccess { continue }
            if case .privileged(let setting) = tweak.mechanism, seenCommands.insert(setting.probe.command).inserted {
                uniqueCommands.append(setting.probe.command)
            }
        }

        let commandsRunner = system.commands
        let outputs: [Command: CommandOutput] = await withTaskGroup(of: (Command, CommandOutput?).self) { group in
            var pending = uniqueCommands.makeIterator()
            for _ in 0..<8 {
                guard let command = pending.next() else { break }
                group.addTask { (command, try? await commandsRunner.run(command)) }
            }
            var collected: [Command: CommandOutput] = [:]
            collected.reserveCapacity(uniqueCommands.count)
            for await (command, output) in group {
                if let output { collected[command] = output }
                if let next = pending.next() {
                    group.addTask { (next, try? await commandsRunner.run(next)) }
                }
            }
            return collected
        }

        let hasBattery = Self.hasBattery(in: outputs[Self.batteryProbe])
        let hiddenLibrary = try? system.fileFlags.isHidden(libraryURL)
        var states: [Tweak.ID: TweakState] = [:]
        states.reserveCapacity(tweaks.count)
        for tweak in tweaks {
            if tweak.requiresBattery, !hasBattery {
                states[tweak.id] = .unknown
                continue
            }
            if tweak.requiresFullDiskAccess, !hasFullDiskAccess {
                states[tweak.id] = .unknown
                continue
            }
            switch tweak.mechanism {
            case .preferences(let bindings):
                states[tweak.id] = preferenceState(of: tweak, bindings: bindings)
            case .libraryVisibility:
                states[tweak.id] = hiddenLibrary.map { .option($0 ? TweakOption.off.id : TweakOption.on.id) } ?? .unknown
            case .privileged(let setting):
                if let output = outputs[setting.probe.command], let option = probeOption(setting.probe, in: output, of: tweak) {
                    states[tweak.id] = .option(option)
                } else {
                    states[tweak.id] = .unknown
                }
            }
        }
        return states
    }

    public func state(of tweak: Tweak) async -> TweakState {
        if tweak.requiresBattery {
            let output = try? await system.commands.run(Self.batteryProbe)
            guard Self.hasBattery(in: output) else { return .unknown }
        }
        // Without access, a protected app's settings read as if they had
        // never been changed, which would be a wrong answer.
        if tweak.requiresFullDiskAccess, !system.hasFullDiskAccess() { return .unknown }
        switch tweak.mechanism {
        case .preferences(let bindings):
            return preferenceState(of: tweak, bindings: bindings)
        case .libraryVisibility:
            guard let hidden = try? system.fileFlags.isHidden(libraryURL) else { return .unknown }
            return .option(hidden ? TweakOption.off.id : TweakOption.on.id)
        case .privileged(let setting):
            guard let option = await probe(setting.probe, of: tweak) else { return .unknown }
            return .option(option)
        }
    }

    private func preferenceState(of tweak: Tweak, bindings: [PreferenceBinding]) -> TweakState {
        let stored = bindings.map { system.preferences.value(for: $0.key, path: $0.path, in: $0.domain) }

        let match = tweak.options.first { option in
            var matchedStoredValue = false
            let allSatisfied = zip(bindings, stored).allSatisfy { binding, have in
                if binding.ignoredWhenReading.contains(option.id) { return true }
                switch (binding.values[option.id], have) {
                case (nil, nil):
                    return true
                case let (want?, have?):
                    guard want.matches(have) else { return false }
                    matchedStoredValue = true
                    return true
                // An absent key means the system default, which is the stock option.
                case (let want?, nil):
                    if option.id == tweak.stockOptionID { return true }
                    if let fallback = binding.valueWhenUnset { return want.matches(fallback) }
                    return binding.isOptionalOnRead
                case (nil, _?):
                    return false
                }
            }
            guard allSatisfied else { return false }
            return option.id == tweak.stockOptionID || matchedStoredValue || bindings.allSatisfy { $0.values[option.id] == nil }
        }
        if let match { return .option(match.id) }

        // A value nobody listed is still a proper state for a setting that
        // takes any number or any text.
        if let input = tweak.input, bindings.count == 1, let have = stored[0] {
            switch (input, have) {
            case (.number, .int), (.number, .double), (.text, .string):
                return .option(tweak.entryID(for: have))
            default:
                break
            }
        }

        let raw = stored.map { $0?.displayText ?? "not set" }.joined(separator: ", ")
        return .custom(raw)
    }

    /// Runs a read-only check. Returns the matching option, or `nil` if the
    /// answer couldn't be read.
    private func probe(_ probe: Probe, of tweak: Tweak) async -> TweakOption.ID? {
        guard let output = try? await system.commands.run(probe.command) else { return nil }
        return probeOption(probe, in: output, of: tweak)
    }

    private func probeOption(_ probe: Probe, in output: CommandOutput, of tweak: Tweak) -> TweakOption.ID? {
        if let option = probe.option(for: output) { return option }
        return probe.capturedValue(in: output).map { tweak.entryID(for: .string($0)) }
    }

    /// The root commands that put a system-wide setting into `option`.
    private func commands(for option: TweakOption.ID, of tweak: Tweak, _ setting: PrivilegedSetting) -> [Command] {
        if let listed = setting.commands[option] { return listed }
        guard let value = tweak.entry(option)?.displayText else { return [] }
        return setting.valueCommands.map { template in
            Command(
                executable: template.executable,
                arguments: template.arguments.map { $0 == PrivilegedSetting.valuePlaceholder ? value : $0 },
                toleratesFailure: template.toleratesFailure
            )
        }
    }

    // MARK: Planning

    /// Builds the plan that moves each tweak to the requested option.
    public func plan(_ requests: [(tweak: Tweak, option: TweakOption.ID)]) -> ChangePlan {
        ChangePlan(changes: requests.map { request in
            PlannedChange(
                tweak: request.tweak,
                target: .option(request.option),
                operations: operations(for: request.tweak, option: request.option)
            )
        })
    }

    /// Builds the plan that puts each tweak back to a recorded snapshot.
    public func revertPlan(_ requests: [(tweak: Tweak, snapshot: Snapshot)]) -> ChangePlan {
        ChangePlan(changes: requests.map { request in
            PlannedChange(
                tweak: request.tweak,
                target: .restore(request.snapshot),
                operations: operations(for: request.tweak, restoring: request.snapshot)
            )
        })
    }

    private func operations(for tweak: Tweak, option: TweakOption.ID) -> [Operation] {
        switch tweak.mechanism {
        case .preferences(let bindings):
            bindings.flatMap {
                Self.preferenceOperations(domain: $0.domain, path: $0.path, key: $0.key, value: $0.values[option] ?? tweak.entry(option))
            }
        case .libraryVisibility:
            [.setLibraryHidden(option == TweakOption.off.id)]
        case .privileged(let setting):
            commands(for: option, of: tweak, setting).map(Operation.privileged)
        }
    }

    private func operations(for tweak: Tweak, restoring snapshot: Snapshot) -> [Operation] {
        switch (tweak.mechanism, snapshot) {
        case (.preferences, .preferences(let keys)):
            keys.flatMap {
                Self.preferenceOperations(domain: $0.domain, path: $0.path, key: $0.key, value: $0.value)
            }
        case (.libraryVisibility, .libraryHidden(let hidden)):
            [.setLibraryHidden(hidden)]
        case (.privileged(let setting), .privileged(let option?)):
            commands(for: option, of: tweak, setting).map(Operation.privileged)
        default:
            []
        }
    }

    private static func preferenceOperations(
        domain: PreferenceDomain, path: [String], key: String, value: PreferenceValue?
    ) -> [Operation] {
        var list: [Operation] = [.writePreference(domain: domain, path: path, key: key, value: value)]
        if domain.isDirectSystemFile, case .system(let plistPath) = domain {
            // Direct plist writes as root leave mode 0600, hiding the file
            // from MacKit and non-root system services.
            list.append(.privileged(Command(
                executable: "/bin/chmod",
                arguments: ["644", plistPath + ".plist"],
                toleratesFailure: value == nil
            )))
        }
        return list
    }

    // MARK: Applying

    /// Applies a plan and reports how each change ended.
    ///
    /// Changes that need root are gathered into a single authorization, so
    /// the user is asked for a password at most once. A failed change never
    /// stops the ones after it.
    public func apply(
        _ plan: ChangePlan,
        onProgress: (Tweak.ID, ChangeProgress) -> Void = { _, _ in }
    ) async -> [ChangeResult] {
        var results: [Tweak.ID: ChangeResult] = [:]

        for change in plan.changes where !change.isPrivileged {
            onProgress(change.id, .running)
            let result = applyUnprivileged(change)
            results[change.id] = result
            onProgress(change.id, .finished(result.outcome))
        }

        let privileged = plan.changes.filter(\.isPrivileged)
        if !privileged.isEmpty {
            var snapshots: [Tweak.ID: Snapshot] = [:]
            for change in privileged {
                onProgress(change.id, .running)
                snapshots[change.id] = await snapshot(of: change.tweak)
            }
            let groups = privileged.map { change in
                PrivilegedGroup(id: change.id, commands: change.operations.compactMap(\.privilegedCommand))
            }
            do {
                let outcomes = try await system.privileged.runAsAdministrator(groups)
                for change in privileged {
                    let outcome: ChangeOutcome = switch outcomes[change.id] {
                    case .success?: .applied
                    case .failure(let error)?: .failed(error)
                    case nil: .failed(.authorizationFailed("The administrator command didn't finish."))
                    }
                    results[change.id] = ChangeResult(
                        change: change,
                        snapshot: outcome.isApplied ? snapshots[change.id] : nil,
                        outcome: outcome
                    )
                    onProgress(change.id, .finished(outcome))
                }
            } catch {
                let outcome = ChangeOutcome.failed(error)
                for change in privileged {
                    results[change.id] = ChangeResult(change: change, snapshot: nil, outcome: outcome)
                    onProgress(change.id, .finished(outcome))
                }
            }
        }

        let applied = Set(results.values.filter { $0.outcome.isApplied }.map(\.id))
        for target in RestartTarget.allCases {
            let needed = plan.changes.contains { applied.contains($0.id) && $0.tweak.effect == .restarts(target) }
            if needed {
                // A process that isn't running makes `killall` exit non-zero.
                // That's fine: it will read the new values when it next starts.
                _ = try? await system.commands.run(Command("/usr/bin/killall", target.processName))
            }
        }

        let signals = Set(plan.changes.filter { applied.contains($0.id) }.compactMap(\.tweak.liveSignal))
        for signal in LiveSignal.allCases where signals.contains(signal) {
            system.announce(signal)
        }

        return plan.changes.compactMap { results[$0.id] }
    }

    private func applyUnprivileged(_ change: PlannedChange) -> ChangeResult {
        let before = unprivilegedSnapshot(of: change.tweak)
        var completed: [Operation] = []
        do {
            for operation in change.operations {
                try perform(operation)
                completed.append(operation)
            }
            return ChangeResult(change: change, snapshot: before, outcome: .applied)
        } catch {
            // Don't leave a tweak half-written: put back whatever was changed
            // before the failure.
            if let before, !completed.isEmpty {
                for operation in operations(for: change.tweak, restoring: before) {
                    try? perform(operation)
                }
            }
            return ChangeResult(change: change, snapshot: nil, outcome: .failed(error))
        }
    }

    private func perform(_ operation: Operation) throws(SystemError) {
        switch operation {
        case .writePreference(let domain, let path, let key, let value):
            try system.preferences.set(value, for: key, path: path, in: domain)
        case .setLibraryHidden(let hidden):
            try system.fileFlags.setHidden(hidden, libraryURL)
        case .privileged(let command):
            // Privileged operations are batched in `apply` and never reach here.
            throw .commandNotAllowed(command.executable)
        }
    }

    // MARK: Snapshots

    private func snapshot(of tweak: Tweak) async -> Snapshot? {
        if case .privileged(let setting) = tweak.mechanism {
            return .privileged(await probe(setting.probe, of: tweak))
        }
        return unprivilegedSnapshot(of: tweak)
    }

    private func unprivilegedSnapshot(of tweak: Tweak) -> Snapshot? {
        switch tweak.mechanism {
        case .preferences(let bindings):
            .preferences(bindings.map {
                PreferenceSnapshot(
                    domain: $0.domain, path: $0.path, key: $0.key,
                    value: system.preferences.value(for: $0.key, path: $0.path, in: $0.domain)
                )
            })
        case .libraryVisibility:
            (try? system.fileFlags.isHidden(libraryURL)).map(Snapshot.libraryHidden)
        case .privileged:
            nil
        }
    }
}
