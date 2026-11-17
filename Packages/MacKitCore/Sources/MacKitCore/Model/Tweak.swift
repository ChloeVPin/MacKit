import Foundation

/// One setting MacKit can change.
///
/// A tweak is data, not code: a fixed list of options and a description of
/// how each option is written to the system. Keeping the catalog declarative
/// means every change can be shown to the user before it runs, and tested
/// without touching the machine.
public struct Tweak: Identifiable, Hashable, Sendable {
    public typealias ID = String

    public let id: ID
    public let title: String
    /// One plain-English sentence describing what the setting does.
    public let summary: String
    public let category: TweakCategory
    /// The group this setting is shown under within its category.
    public let section: String
    /// The states this setting can be in, in display order.
    public let options: [TweakOption]
    /// The option macOS ships with.
    public let stockOptionID: TweakOption.ID
    public let mechanism: Mechanism
    /// What has to happen before the change is visible.
    public let effect: Effect
    /// A sentence of warning for settings with a real downside, such as
    /// weaker security or shorter battery life. `nil` for everything else.
    public let caution: String?
    /// Set when the setting takes a number or text the user enters.
    public let input: ValueInput?
    /// Whether macOS ships with a value for this setting. A computer's name
    /// has none, so it can't be "reset" and never counts as customized.
    public let hasDefault: Bool
    /// Whether this setting only makes sense on a Mac laptop with a battery.
    public let requiresBattery: Bool

    public init(
        id: ID,
        title: String,
        summary: String,
        category: TweakCategory,
        section: String,
        options: [TweakOption],
        stock: TweakOption.ID,
        mechanism: Mechanism,
        effect: Effect = .immediate,
        caution: String? = nil,
        input: ValueInput? = nil,
        hasDefault: Bool = true,
        requiresBattery: Bool = false
    ) {
        precondition(options.count >= 2 || input != nil, "\(id): a tweak needs at least two options, or an input")
        precondition(!hasDefault || options.contains { $0.id == stock }, "\(id): stock option is not one of the options")
        precondition(!options.contains { $0.id.hasPrefix("=") }, "\(id): option identifiers can't start with =")
        self.id = id
        self.title = title
        self.summary = summary
        self.category = category
        self.section = section
        self.options = options
        self.stockOptionID = stock
        self.mechanism = mechanism
        self.effect = effect
        self.caution = caution
        self.input = input
        self.hasDefault = hasDefault
        self.requiresBattery = requiresBattery
    }

    /// Whether the tweak is a plain on/off setting.
    public var isToggle: Bool {
        options.count == 2 && options.contains { $0.id == TweakOption.on.id } && options.contains { $0.id == TweakOption.off.id }
    }

    public var requiresAdministrator: Bool {
        switch mechanism {
        case .privileged: true
        case .preferences(let bindings): bindings.contains { $0.domain.requiresAdministrator }
        case .libraryVisibility: false
        }
    }

    /// Whether the setting should be hidden on a Mac where it can't be read.
    public var isHardwareDependent: Bool {
        if requiresBattery { return true }
        if case .privileged(let setting) = mechanism { return setting.isHardwareDependent }
        return false
    }

    public func option(_ id: TweakOption.ID) -> TweakOption? {
        options.first { $0.id == id }
    }

    /// The option macOS ships with, for settings that have one.
    public var stockOption: TweakOption? {
        options.first { $0.id == stockOptionID }
    }
}

public struct TweakOption: Identifiable, Hashable, Sendable {
    public typealias ID = String

    public let id: ID
    public let label: String

    public init(_ id: ID, _ label: String) {
        self.id = id
        self.label = label
    }

    public static let on = TweakOption("on", "On")
    public static let off = TweakOption("off", "Off")
    public static let toggle: [TweakOption] = [.off, .on]
}

public enum TweakCategory: String, CaseIterable, Identifiable, Sendable, Codable {
    case finder
    case desktop
    case dock
    case missionControl
    case windows
    case appearance
    case menuBar
    case sound
    case accessibility
    case keyboard
    case trackpad
    case screenshots
    case apps
    case power
    case sharing
    case security
    case updates
    case system

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .finder: "Finder"
        case .desktop: "Desktop"
        case .dock: "Dock"
        case .missionControl: "Mission Control"
        case .windows: "Windows"
        case .appearance: "Appearance"
        case .menuBar: "Menu Bar"
        case .sound: "Sound"
        case .keyboard: "Keyboard"
        case .trackpad: "Trackpad & Mouse"
        case .screenshots: "Screenshots"
        case .apps: "Apps"
        case .accessibility: "Accessibility"
        case .power: "Battery & Energy"
        case .sharing: "Sharing & Network"
        case .security: "Privacy & Security"
        case .updates: "Software Update"
        case .system: "Startup & Login"
        }
    }

    public var blurb: String {
        switch self {
        case .finder: "How files and folders are shown."
        case .desktop: "Desktop icons, widgets, and Stage Manager."
        case .dock: "How the Dock looks and behaves."
        case .missionControl: "Spaces, gestures, and hot corners."
        case .windows: "Dialogs, tiling, tabs, and scroll bars."
        case .appearance: "Colors, motion, and the look of macOS."
        case .menuBar: "The clock and what sits beside it."
        case .sound: "Alerts and interface sounds."
        case .keyboard: "Keys, shortcuts, and automatic corrections."
        case .trackpad: "Clicks, gestures, and pointer speed."
        case .screenshots: "Where captures go and how they look."
        case .apps: "Hidden settings in the apps that come with your Mac."
        case .accessibility: "Motion, contrast, and the pointer."
        case .power: "Sleep, battery life, and performance."
        case .sharing: "What this Mac offers to other devices."
        case .security: "Firewall, accounts, and what's shared with Apple."
        case .updates: "What installs by itself, and when."
        case .system: "Startup, the login window, and the clock."
        }
    }

    /// Where the category sits in the sidebar.
    public var group: Group {
        switch self {
        case .finder, .desktop, .dock, .missionControl, .windows: .desktop
        case .appearance, .menuBar, .sound, .accessibility: .look
        case .keyboard, .trackpad: .input
        case .screenshots, .apps: .apps
        case .power, .sharing, .security, .updates, .system: .system
        }
    }

    public enum Group: String, CaseIterable, Identifiable, Sendable {
        case desktop = "Desktop"
        case look = "Look and Feel"
        case input = "Input"
        case apps = "Apps"
        case system = "System"

        public var id: String { rawValue }
        public var title: String { rawValue }
        public var categories: [TweakCategory] { TweakCategory.allCases.filter { $0.group == self } }
    }
}

/// How a tweak's options are written to the system.
public enum Mechanism: Hashable, Sendable {
    /// One or more preference keys that are written together.
    case preferences([PreferenceBinding])
    /// The hidden flag on the user's `~/Library` folder.
    case libraryVisibility
    /// A system-wide setting that needs root to change.
    case privileged(PrivilegedSetting)
}

/// Maps each option of a tweak to the value of one preference key.
public struct PreferenceBinding: Hashable, Sendable {
    public let domain: PreferenceDomain
    /// Dictionary keys above `key`, outermost first, for settings stored
    /// inside a nested dictionary. Empty for top-level keys.
    public let path: [String]
    public let key: String
    /// The value to write for each option. An option missing from this
    /// dictionary removes the key, which returns the setting to the system
    /// default.
    public let values: [TweakOption.ID: PreferenceValue]
    /// Options for which any stored value on disk is accepted when reading,
    /// such as `AppleInterfaceStyle` while Automatic appearance is on.
    public let ignoredWhenReading: Set<TweakOption.ID>
    /// Whether an unset value for this key is allowed when another key of
    /// the same setting matches a non-default option, such as a companion
    /// key or a second trackpad domain that hasn't been written yet.
    public let isOptionalOnRead: Bool
    /// The value macOS treats an unset key as having, when needed to tell two
    /// non-default options of a multi-key setting apart.
    public let valueWhenUnset: PreferenceValue?

    public init(
        _ domain: PreferenceDomain,
        path: [String] = [],
        _ key: String,
        _ values: [TweakOption.ID: PreferenceValue],
        ignoredWhenReading: Set<TweakOption.ID> = [],
        isOptionalOnRead: Bool = false,
        valueWhenUnset: PreferenceValue? = nil
    ) {
        self.domain = domain
        self.path = path
        self.key = key
        self.values = values
        self.ignoredWhenReading = ignoredWhenReading
        self.isOptionalOnRead = isOptionalOnRead
        self.valueWhenUnset = valueWhenUnset
    }
}

public struct PrivilegedSetting: Hashable, Sendable {
    public let probe: Probe
    /// The commands that put the system into each option's state.
    public let commands: [TweakOption.ID: [Command]]
    /// Where the setting is kept, in a few words, for people who want to
    /// find it themselves. For example "Power Management" or "NVRAM".
    public let storage: String
    /// Whether the setting exists only on some Macs, such as battery
    /// settings. When its state can't be read, it is left out entirely.
    public let isHardwareDependent: Bool
    /// The commands that store an entered value. Every argument that is
    /// exactly `{value}` is replaced by what the user entered.
    public let valueCommands: [Command]

    public static let valuePlaceholder = "{value}"

    public init(
        storage: String, probe: Probe, commands: [TweakOption.ID: [Command]],
        isHardwareDependent: Bool = false, valueCommands: [Command] = []
    ) {
        self.storage = storage
        self.isHardwareDependent = isHardwareDependent
        self.valueCommands = valueCommands
        self.probe = probe
        self.commands = commands
    }
}

/// A read-only check of a system-wide setting: a command that never needs
/// root, and how to tell from its output which option is in effect.
public struct Probe: Hashable, Sendable {
    public struct Match: Hashable, Sendable {
        public let option: TweakOption.ID
        /// A regular expression searched for in the command's output,
        /// ignoring case. `.` matches line breaks too.
        public let pattern: String
        /// Output the command really prints in this state. Used to check the
        /// pattern, and as the fake system's answer.
        public let example: String

        public init(_ option: TweakOption.ID, _ pattern: String, example: String) {
            self.option = option
            self.pattern = pattern
            self.example = example
        }
    }

    public let command: Command
    /// Tried in order; the first pattern found in the output wins.
    public let matches: [Match]
    /// The option in effect when the command exits with an error, for tools
    /// that fail when a value has never been set.
    public let onFailure: TweakOption.ID?
    /// For settings that hold an entered value: how to pull it out of the
    /// output when none of `matches` applies.
    public let capture: Capture?

    public struct Capture: Hashable, Sendable {
        /// A regular expression whose first group is the value.
        public let pattern: String
        /// Real output, with `{value}` where the value appears.
        public let example: String

        public init(_ pattern: String, example: String) {
            self.pattern = pattern
            self.example = example
        }
    }

    public init(_ command: Command, _ matches: [Match], onFailure: TweakOption.ID? = nil, capture: Capture? = nil) {
        self.command = command
        self.matches = matches
        self.onFailure = onFailure
        self.capture = capture
    }

    /// The entered value that `output` shows, as plain text.
    public func capturedValue(in output: CommandOutput) -> String? {
        guard output.exitCode == 0, let capture, let regex = try? Regex(capture.pattern) else { return nil }
        let text = output.standardOutput + output.standardError
        guard let match = text.firstMatch(of: regex.ignoresCase()), match.output.count > 1,
              let range = match.output[1].range else { return nil }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The option that `output` shows to be in effect.
    public func option(for output: CommandOutput) -> TweakOption.ID? {
        guard output.exitCode == 0 else { return onFailure }
        let text = output.standardOutput + output.standardError
        return matches.first { match in
            guard let regex = try? Regex(match.pattern) else { return false }
            return text.contains(regex.ignoresCase().dotMatchesNewlines())
        }?.option
    }
}

/// What has to happen before a change becomes visible.
public enum Effect: Hashable, Sendable {
    case immediate
    /// A system process is restarted. It relaunches on its own within a second.
    case restarts(RestartTarget)
    /// Running apps pick the change up the next time they launch.
    case appRelaunch
    /// Applies after logging out and back in.
    case logout
    /// Applies the next time the Mac starts up.
    case nextStartup
    /// Applies after the Mac is restarted.
    case restart
}

/// Something macOS has to be told after a setting is saved. Saving alone
/// only reaches apps the next time they start; System Settings follows each
/// save with one of these, and so does MacKit.
public enum LiveSignal: Hashable, Sendable, CaseIterable {
    case appearance, glass, wallpaperTint, scrollBars, sidebarSize, menuBar
    case pointerSize, keyboardNavigation, inputDevices
    case reduceMotion, reduceTransparency, increaseContrast, differentiateWithoutColor, buttonShapes
}

extension Tweak {
    /// The signal that makes this setting apply to what's already running,
    /// if macOS has one for it.
    public var liveSignal: LiveSignal? {
        guard case .preferences(let bindings) = mechanism else { return nil }
        for binding in bindings {
            switch (binding.domain, binding.key) {
            case (.global, "AppleInterfaceStyle"), (.global, "AppleAccentColor"): return .appearance
            case (.global, "NSGlassTintAmount"): return .glass
            case (.global, "AppleReduceDesktopTinting"): return .wallpaperTint
            case (.global, "AppleShowScrollBars"): return .scrollBars
            case (.global, "NSTableViewDefaultSizeMode"): return .sidebarSize
            case (.global, "_HIHideMenuBar"), (.global, "AppleMenuBarVisibleInFullscreen"): return .menuBar
            case (.global, "AppleKeyboardUIMode"): return .keyboardNavigation
            case (.app("com.apple.universalaccess"), "mouseDriverCursorSize"): return .pointerSize
            case (.app("com.apple.universalaccess"), "reduceMotion"): return .reduceMotion
            case (.app("com.apple.universalaccess"), "reduceTransparency"): return .reduceTransparency
            case (.app("com.apple.universalaccess"), "increaseContrast"): return .increaseContrast
            case (.app("com.apple.universalaccess"), "differentiateWithoutColor"): return .differentiateWithoutColor
            case (.app("com.apple.universalaccess"), "showToolbarButtonShapes"): return .buttonShapes
            case (.app("com.apple.AppleMultitouchTrackpad"), _), (.app("com.apple.AppleMultitouchMouse"), _),
                (.global, "com.apple.keyboard.fnState"), (.global, "com.apple.swipescrolldirection"):
                return .inputDevices
            case (.global, let key) where key.hasPrefix("com.apple.trackpad.") || key.hasPrefix("com.apple.mouse."):
                return .inputDevices
            default: continue
            }
        }
        return nil
    }
}

public enum RestartTarget: String, Hashable, Sendable, Codable, CaseIterable {
    case finder = "Finder"
    case dock = "Dock"
    case systemUIServer = "SystemUIServer"
    case controlCenter = "ControlCenter"
    case windowManager = "WindowManager"
    case notificationCenter = "NotificationCenter"

    public var processName: String { rawValue }

    public var displayName: String {
        switch self {
        case .finder: "Finder"
        case .dock: "the Dock"
        case .systemUIServer: "the menu bar"
        case .controlCenter: "Control Center"
        case .windowManager: "window management"
        case .notificationCenter: "Notification Center"
        }
    }
}

/// An executable and its arguments. Never a shell string.
public struct Command: Hashable, Sendable, Codable {
    public let executable: String
    public let arguments: [String]
    /// Whether the commands after this one still run if it fails. For
    /// commands that fail harmlessly, such as removing a key that isn't set.
    public var toleratesFailure = false

    public init(_ executable: String, _ arguments: String...) {
        precondition(executable.hasPrefix("/"), "Commands must use an absolute path")
        self.executable = executable
        self.arguments = arguments
    }

    public init(executable: String, arguments: [String], toleratesFailure: Bool = false) {
        precondition(executable.hasPrefix("/"), "Commands must use an absolute path")
        self.executable = executable
        self.arguments = arguments
        self.toleratesFailure = toleratesFailure
    }

    /// The command as it would be typed in a POSIX shell, with every word
    /// quoted where needed. Safe to hand to `sh`.
    public var shellText: String {
        ([executable] + arguments).map(Self.quote).joined(separator: " ")
    }

    static func quote(_ word: String) -> String {
        let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_./=:%+,@")
        if !word.isEmpty, word.unicodeScalars.allSatisfy(safe.contains) {
            return word
        }
        return "'" + word.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
