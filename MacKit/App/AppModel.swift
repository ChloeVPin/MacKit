import MacKitCore
import Observation
import SwiftUI

/// Where the main window is pointed.
enum Destination: Hashable {
    case home
    /// The app store: browse and install apps.
    case discover
    /// Apps from the store that are on this Mac.
    case installed
    case category(TweakCategory)
    case history

    /// Every destination, in sidebar order.
    static let all: [Destination] = [.home, .discover, .installed] + TweakCategory.allCases.map(Destination.category) + [.history]

    var isStore: Bool { self == .discover || self == .installed }
}

/// The app's state: what this Mac is set to, what the user has chosen to
/// change, and what has been applied before.
///
/// Flipping a switch never changes the system. It marks a pending change, and
/// nothing is written until the user reviews and applies the whole set.
@Observable
final class AppModel {
    private(set) var tweaks: [Tweak]
    let engine: TweakEngine
    private let historyStore: HistoryStore?
    /// The app store. Separate from settings: installing an app happens
    /// when you click, not through the review sheet.
    let store: StoreModel

    /// What each tweak is currently set to on this Mac.
    private(set) var states: [Tweak.ID: TweakState] = [:]
    /// The option the user wants for each tweak they've changed.
    private(set) var pending: [Tweak.ID: TweakOption.ID] = [:]
    /// Applied batches, newest first.
    private(set) var history: [HistoryRecord] = []
    private(set) var machine: MachineInfo?
    private(set) var isLoaded = false
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    /// The value each control shows while its instant change is written.
    private(set) var applying: [Tweak.ID: TweakOption.ID] = [:]
    @ObservationIgnored private var instantTasks: [Tweak.ID: Task<Void, Never>] = [:]
    /// The History record that instant changes are currently added to.
    @ObservationIgnored private var instantRecordID: HistoryRecord.ID?

    var destination: Destination = .home
    /// The setting whose own page is showing, if any.
    var openTweakID: Tweak.ID?
    var searchText = ""
    /// Incremented to ask the window to focus its search field.
    var searchFocusRequests = 0
    /// The change set being reviewed or applied, shown as a sheet.
    var review: ReviewSession?
    var errorMessage: String?

    init(
        tweaks: [Tweak], engine: TweakEngine, historyStore: HistoryStore?, history: [HistoryRecord] = [],
        store: StoreModel = StoreModel(backend: LiveStoreBackend())
    ) {
        self.store = store
        self.tweaks = tweaks
        self.engine = engine
        self.historyStore = historyStore
        self.history = history
    }

    /// The model wired to the real system.
    static func live() -> AppModel {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let system = SystemAccess(
            preferences: SystemPreferenceStore(),
            commands: AllowlistedCommandRunner(),
            privileged: AdministratorPromptRunner(),
            fileFlags: SystemFileFlagStore(),
            homeDirectory: home,
            hasFullDiskAccess: { MacKitCore.hasFullDiskAccess(home: home) },
            announce: announceToSystem
        )
        return AppModel(
            tweaks: Catalog.tweaks(home: home),
            engine: TweakEngine(system: system),
            historyStore: .standard()
        )
    }

    // MARK: Loading

    /// Reads the system once. Later calls wait for the same read.
    func load() async {
        if loadTask == nil {
            loadTask = Task { await performLoad() }
        }
        await loadTask?.value
    }

    private func performLoad() async {
        if let historyStore {
            do {
                history = try historyStore.load()
            } catch {
                errorMessage = "MacKit couldn't read its history file, so earlier changes aren't listed. \(error.localizedDescription)"
            }
        }
        async let loadedStates = engine.states(of: tweaks)
        async let loadedMachine = MachineInfo.current(using: engine.system.commands)
        states = await loadedStates
        // Settings this Mac doesn't have, such as battery settings on a
        // desktop, are left out rather than shown as unknown.
        tweaks.removeAll { $0.isHardwareDependent && states[$0.id] == .unknown }
        isLoaded = true
        machine = await loadedMachine
    }

    /// Re-reads every setting from the system, for example after the user
    /// changed something in System Settings.
    func refresh() async {
        states = await engine.states(of: tweaks)
        // A pending change that now matches the system has nothing left to do.
        pending = pending.filter { id, option in states[id] != .option(option) }
    }

    // MARK: Reading state

    func tweak(_ id: Tweak.ID) -> Tweak? {
        tweaks.first { $0.id == id }
    }

    func tweaks(in category: TweakCategory) -> [Tweak] {
        tweaks.filter { $0.category == category }
    }

    func state(of tweak: Tweak) -> TweakState {
        states[tweak.id] ?? .unknown
    }

    /// The option a control should show: the pending one if there is one,
    /// otherwise what the system is set to.
    func selectedOption(for tweak: Tweak) -> TweakOption.ID? {
        pending[tweak.id] ?? applying[tweak.id] ?? state(of: tweak).optionID
    }

    func isPending(_ tweak: Tweak) -> Bool {
        pending[tweak.id] != nil
    }

    /// Whether the tweak is set to something other than what macOS ships with.
    func isCustomized(_ tweak: Tweak) -> Bool {
        guard tweak.hasDefault else { return false }
        return switch state(of: tweak) {
        case .option(let id): id != tweak.stockOptionID
        case .custom: true
        case .unknown: false
        }
    }

    /// How a state reads in the interface: "On", "PNG", "Custom".
    func label(for state: TweakState, of tweak: Tweak) -> String {
        switch state {
        case .option(let id): tweak.label(for: id)
        case .custom: "Custom"
        case .unknown: "Unknown"
        }
    }

    var customizedCount: Int { tweaks.count(where: isCustomized) }

    func customizedCount(in category: TweakCategory) -> Int {
        tweaks(in: category).count(where: isCustomized)
    }

    func pendingCount(in category: TweakCategory) -> Int {
        tweaks(in: category).count(where: isPending)
    }

    /// Pending changes in catalog order, so the review reads the same way the
    /// app does.
    var pendingChanges: [(tweak: Tweak, option: TweakOption.ID)] {
        tweaks.compactMap { tweak in pending[tweak.id].map { (tweak, $0) } }
    }

    var searchResults: [Tweak] {
        Catalog.search(searchText, in: tweaks)
    }

    // MARK: Full Disk Access

    /// Whether the setting belongs to an app whose preferences macOS keeps
    /// locked away until MacKit is given Full Disk Access.
    func isLocked(_ tweak: Tweak) -> Bool {
        tweak.requiresFullDiskAccess && !engine.system.hasFullDiskAccess()
    }

    /// Opens the Full Disk Access list in System Settings.
    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Choosing values

    /// Chooses an option for a setting.
    ///
    /// A small, safe setting is written straight away. Anything weightier is
    /// marked as a pending change and waits for review.
    ///
    /// - Parameter staged: Pass `true` to always wait for review, for
    ///   actions that change many settings at once.
    func select(_ option: TweakOption.ID, for tweak: Tweak, staged: Bool = false) {
        guard !isLocked(tweak) else { return }
        if tweak.appliesInstantly, !staged, review == nil {
            applyInstantly(option, to: tweak)
        } else if state(of: tweak) == .option(option) {
            pending[tweak.id] = nil
        } else {
            pending[tweak.id] = option
        }
    }

    // MARK: Applying instantly

    private func applyInstantly(_ option: TweakOption.ID, to tweak: Tweak) {
        pending[tweak.id] = nil
        instantTasks[tweak.id]?.cancel()
        // The control shows the new value at once; the write follows.
        applying[tweak.id] = option

        instantTasks[tweak.id] = Task {
            // A slider reports every point it passes. Wait for it to settle
            // so the setting is written once, where it came to rest.
            if case .number = tweak.input {
                try? await Task.sleep(for: .milliseconds(450))
            }
            guard !Task.isCancelled else { return }

            let before = label(for: state(of: tweak), of: tweak)
            if state(of: tweak) != .option(option) {
                let results = await engine.apply(engine.plan([(tweak, option)]))
                if let result = results.first, result.outcome.isApplied, let snapshot = result.snapshot {
                    record(tweak, from: before, to: tweak.label(for: option), snapshot: snapshot)
                } else if case .failed(let error)? = results.first?.outcome {
                    errorMessage = "“\(tweak.title)” couldn't be changed. \(error.explanation)"
                }
                states[tweak.id] = await engine.state(of: tweak)
            }
            // A newer choice may have replaced this one while it was written.
            if !Task.isCancelled, applying[tweak.id] == option {
                applying[tweak.id] = nil
                instantTasks[tweak.id] = nil
            }
        }
    }

    /// Adds an instant change to History. Changes made within a couple of
    /// minutes of each other share one entry in the list, and changing the
    /// same setting twice keeps the first "before", so Undo goes all the way
    /// back.
    private func record(_ tweak: Tweak, from: String, to: String, snapshot: Snapshot) {
        let entry = HistoryEntry(
            tweakID: tweak.id, title: tweak.title, category: tweak.category, section: tweak.section,
            from: from, to: to, snapshot: snapshot
        )
        if let latest = history.first, latest.id == instantRecordID, Date.now.timeIntervalSince(latest.date) < 120 {
            if let index = latest.entries.firstIndex(where: { $0.tweakID == tweak.id && $0.revertedAt == nil }) {
                let first = latest.entries[index]
                history[0].entries[index] = HistoryEntry(
                    id: first.id, tweakID: tweak.id, title: tweak.title, category: tweak.category, section: tweak.section,
                    from: first.from, to: to, snapshot: first.snapshot
                )
            } else {
                history[0].entries.append(entry)
            }
        } else {
            let record = HistoryRecord(date: .now, entries: [entry])
            instantRecordID = record.id
            history.insert(record, at: 0)
        }
        saveHistory()
    }

    // MARK: Entered values

    /// The number a slider should show: the pending or current value, or
    /// the default when the Mac holds nothing readable.
    func number(for tweak: Tweak, _ input: NumberInput) -> Double {
        let value = selectedOption(for: tweak).flatMap { tweak.entry($0) ?? tweak.storedValue(of: $0) }
        switch value {
        case .int(let stored): return Double(stored)
        case .double(let stored): return stored
        default:
            if case .double(let stock)? = tweak.storedValue(of: tweak.stockOptionID) { return stock }
            if case .int(let stock)? = tweak.storedValue(of: tweak.stockOptionID) { return Double(stock) }
            return input.range.lowerBound
        }
    }

    func setNumber(_ number: Double, for tweak: Tweak, _ input: NumberInput) {
        let snapped = input.snapped(number)
        select(tweak.optionID(for: input.isInteger ? .int(Int(snapped)) : .double(snapped)), for: tweak)
    }

    /// The text a field should show. Empty for the default.
    func text(for tweak: Tweak) -> String {
        guard let id = selectedOption(for: tweak), case .string(let text)? = tweak.entry(id) else { return "" }
        return text
    }

    func setText(_ text: String, for tweak: Tweak, _ input: TextInput) {
        let cleaned = input.cleaned(text)
        if !cleaned.isEmpty {
            select(tweak.entryID(for: .string(cleaned)), for: tweak)
        } else if tweak.hasDefault {
            select(tweak.stockOptionID, for: tweak)
        } else {
            // A setting with no default can't be emptied, so an empty field
            // means "leave it as it is".
            clearPending(tweak)
        }
    }

    func clearPending(_ tweak: Tweak) {
        pending[tweak.id] = nil
    }

    func discardPending() {
        pending.removeAll()
    }

    /// Marks every customized setting in a category to go back to its default.
    func resetToDefaults(_ category: TweakCategory) {
        for tweak in tweaks(in: category) where tweak.hasDefault {
            select(tweak.stockOptionID, for: tweak, staged: true)
        }
    }

    // MARK: Quick setups

    enum SetupStatus: Equatable {
        /// This Mac already matches the setup.
        case alreadySet
        /// Every remaining setting of the setup is pending.
        case selected(changes: Int)
        case available(changes: Int)
    }

    /// The selections of a setup that this Mac doesn't already match.
    private func remaining(_ setup: QuickSetup) -> [(tweak: Tweak, option: TweakOption.ID)] {
        setup.selections.compactMap { selection in
            guard let tweak = tweak(selection.tweakID), state(of: tweak) != .option(selection.option) else { return nil }
            return (tweak, selection.option)
        }
    }

    func status(of setup: QuickSetup) -> SetupStatus {
        let remaining = remaining(setup)
        if remaining.isEmpty { return .alreadySet }
        let isSelected = remaining.allSatisfy { pending[$0.tweak.id] == $0.option }
        return isSelected ? .selected(changes: remaining.count) : .available(changes: remaining.count)
    }

    /// Selects a setup's settings, or deselects them if they're all selected.
    func toggle(_ setup: QuickSetup) {
        let remaining = remaining(setup)
        if case .selected = status(of: setup) {
            for item in remaining { pending[item.tweak.id] = nil }
        } else {
            for item in remaining { pending[item.tweak.id] = item.option }
        }
    }

    // MARK: Navigation

    /// Opens a setting's own page, under its category.
    func open(_ tweak: Tweak) {
        searchText = ""
        destination = .category(tweak.category)
        openTweakID = tweak.id
    }

    func go(to destination: Destination) {
        searchText = ""
        openTweakID = nil
        store.openAppID = nil
        self.destination = destination
    }

    // MARK: Applying

    func beginReview() {
        let changes = pendingChanges
        guard !changes.isEmpty, review == nil else { return }
        let plan = engine.plan(changes)
        review = ReviewSession(
            kind: .apply,
            plan: plan,
            rows: plan.changes.map { change in
                ReviewSession.Row(
                    change: change,
                    from: label(for: state(of: change.tweak), of: change.tweak),
                    to: pending[change.id].map { change.tweak.label(for: $0) } ?? ""
                )
            }
        )
    }

    /// Starts a review that puts the given history entries back to what they
    /// were before MacKit changed them.
    func beginUndo(of entries: [HistoryEntry], in record: HistoryRecord) {
        let undoable = entries.filter(\.canRevert).compactMap { entry in
            tweak(entry.tweakID).map { (entry: entry, tweak: $0) }
        }
        guard !undoable.isEmpty, review == nil else { return }
        let plan = engine.revertPlan(undoable.map { ($0.tweak, $0.entry.snapshot) })
        review = ReviewSession(
            kind: .undo(recordID: record.id, entryIDs: Dictionary(uniqueKeysWithValues: undoable.map { ($0.tweak.id, $0.entry.id) })),
            plan: plan,
            rows: zip(plan.changes, undoable).map { change, item in
                ReviewSession.Row(change: change, from: label(for: state(of: item.tweak), of: item.tweak), to: item.entry.from)
            }
        )
    }

    /// Runs the plan under review. Safe to call once per session.
    func runReview() async {
        guard let session = review, session.phase == .reviewing else { return }
        withAnimation(Motion.state) { session.phase = .running }

        let results = await engine.apply(session.plan) { id, progress in
            withAnimation(Motion.state) { session.progress[id] = progress }
        }
        let applied = results.filter { $0.outcome.isApplied }

        switch session.kind {
        case .apply:
            let entries = applied.compactMap { result -> HistoryEntry? in
                guard let snapshot = result.snapshot, let row = session.rows.first(where: { $0.id == result.id }) else { return nil }
                let changed = result.change.tweak
                return HistoryEntry(
                    tweakID: result.id, title: changed.title, category: changed.category, section: changed.section,
                    from: row.from, to: row.to, snapshot: snapshot
                )
            }
            if !entries.isEmpty {
                history.insert(HistoryRecord(date: .now, entries: entries), at: 0)
            }
            for result in applied { pending[result.id] = nil }

        case .undo(let recordID, let entryIDs):
            if let index = history.firstIndex(where: { $0.id == recordID }) {
                let undone = Set(applied.compactMap { entryIDs[$0.id] })
                for entryIndex in history[index].entries.indices where undone.contains(history[index].entries[entryIndex].id) {
                    history[index].entries[entryIndex].revertedAt = .now
                }
            }
            // The system moved under any pending change to the same setting.
            for result in applied { pending[result.id] = nil }
        }

        saveHistory()
        await refresh()
        withAnimation(Motion.surface) { session.phase = .finished }
    }

    private func saveHistory() {
        guard let historyStore else { return }
        do {
            try historyStore.save(history)
        } catch {
            errorMessage = "The changes were applied, but MacKit couldn't save them to its history. \(error.localizedDescription)"
        }
    }
}

// MARK: Wording

/// How a change reads in a sentence, in the three tenses the app needs.
enum ChangeWording {
    private static func isSwitch(_ from: String, _ to: String) -> Bool {
        Set([from, to]) == ["On", "Off"]
    }

    /// Where a setting sits, such as "Apps · Safari" or "Battery & Energy · On Battery".
    static func location(category: TweakCategory, section: String?) -> String {
        guard let section, !section.isEmpty, section != category.title else { return category.title }
        return "\(category.title) · \(section)"
    }

    /// What applying will do: "Turn on", "Change to Gallery".
    static func action(from: String, to: String) -> String {
        isSwitch(from, to) ? "Turn \(to.lowercased())" : "Change to \(to)"
    }

    /// What was done: "Turned on", "Changed from PNG to JPEG".
    static func past(from: String, to: String) -> String {
        isSwitch(from, to) ? "Turned \(to.lowercased())" : "Changed from \(from) to \(to)"
    }
}
