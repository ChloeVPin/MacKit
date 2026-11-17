import Foundation

private let pmset = "/usr/bin/pmset"
private let report = Command(pmset, "-g", "custom")

/// Where a power setting applies.
private enum Source {
    case battery, adapter, everywhere

    var flag: String {
        switch self {
        case .battery: "-b"
        case .adapter: "-c"
        case .everywhere: "-a"
        }
    }

    var header: String? {
        switch self {
        case .battery: "Battery Power:"
        case .adapter: "AC Power:"
        case .everywhere: nil
        }
    }

    /// A pattern that finds `key value` in this source's part of the report.
    /// For `everywhere`, every part of the report has to agree.
    func pattern(_ key: String, _ value: String) -> String {
        if let header {
            // A section ends at the next header, the next line with a colon.
            return #"\#(header)[^:]*?\b\#(key)\s+\#(value)\b"#
        }
        return #"^(?!.*\b\#(key)\s+(?!\#(value)\b)\S).*\b\#(key)\s+\#(value)\b"#
    }

    func example(_ key: String, _ value: String) -> String {
        (header.map { $0 + "\n" } ?? "") + " \(key) \(value)"
    }
}

extension Catalog {
    /// A setting kept by `pmset`, read from `pmset -g custom`.
    private static func power(
        _ id: Tweak.ID, _ title: String, _ summary: String, _ section: String,
        _ source: Source, _ key: String,
        _ choices: [(id: TweakOption.ID, label: String, value: String)],
        stock: TweakOption.ID,
        caution: String? = nil
    ) -> Tweak {
        Tweak(
            id: id, title: title, summary: summary, category: .power, section: section,
            options: choices.map { TweakOption($0.id, $0.label) },
            stock: stock,
            mechanism: .privileged(PrivilegedSetting(
                storage: "Power Management (pmset \(key))",
                probe: Probe(report, choices.map { choice in
                    Probe.Match(choice.id, source.pattern(key, choice.value), example: source.example(key, choice.value))
                }),
                commands: Dictionary(uniqueKeysWithValues: choices.map { ($0.id, [Command(pmset, source.flag, key, $0.value)]) }),
                // Desktop Macs have no battery section, and some keys exist
                // only on certain models.
                isHardwareDependent: true
            )),
            caution: caution
        )
    }

    private static let onOff: [(id: TweakOption.ID, label: String, value: String)] = [("off", "Off", "0"), ("on", "On", "1")]

    private static let minutes: [(id: TweakOption.ID, label: String, value: String)] = [
        ("1", "1 Minute", "1"), ("2", "2 Minutes", "2"), ("3", "3 Minutes", "3"), ("5", "5 Minutes", "5"),
        ("10", "10 Minutes", "10"), ("15", "15 Minutes", "15"), ("20", "20 Minutes", "20"), ("30", "30 Minutes", "30"),
        ("45", "45 Minutes", "45"), ("60", "1 Hour", "60"), ("90", "1.5 Hours", "90"), ("120", "2 Hours", "120"),
        ("180", "3 Hours", "180"), ("never", "Never", "0"),
    ]

    static let power: [Tweak] = [
        // On battery
        power(
            "power.battery.display", "Turn display off after",
            "How long the screen stays on when you're not using the Mac.", "On Battery",
            .battery, "displaysleep", minutes, stock: "2",
            caution: "Never keeps the screen lit until the battery is empty."
        ),
        power(
            "power.battery.sleep", "Sleep after",
            "How long before the whole Mac goes to sleep.", "On Battery",
            .battery, "sleep", minutes, stock: "1",
            caution: "Never keeps the Mac awake until the battery is empty."
        ),
        power(
            "power.battery.low-power", "Low Power Mode",
            "Trade some speed and brightness for longer battery life.", "On Battery",
            .battery, "lowpowermode", onOff, stock: "off"
        ),
        power(
            "power.battery.power-nap", "Power Nap",
            "Check mail and iCloud now and then while asleep.", "On Battery",
            .battery, "powernap", onOff, stock: "on"
        ),
        power(
            "power.battery.network-wake", "Wake for network access",
            "Let other devices wake this Mac to reach shared files and services.", "On Battery",
            .battery, "womp", onOff, stock: "off"
        ),
        power(
            "power.battery.dim", "Dim the display slightly",
            "Lower the brightness a little when running on battery.", "On Battery",
            .battery, "lessbright", onOff, stock: "on"
        ),

        // Plugged in
        power(
            "power.adapter.display", "Turn display off after",
            "How long the screen stays on when you're not using the Mac.", "Plugged In",
            .adapter, "displaysleep", minutes, stock: "10"
        ),
        power(
            "power.adapter.sleep", "Sleep after",
            "How long before the whole Mac goes to sleep.", "Plugged In",
            .adapter, "sleep", minutes, stock: "1"
        ),
        power(
            "power.adapter.low-power", "Low Power Mode",
            "Run cooler and quieter, a little slower.", "Plugged In",
            .adapter, "lowpowermode", onOff, stock: "off"
        ),
        power(
            "power.adapter.power-nap", "Power Nap",
            "Check mail, back up, and update while asleep.", "Plugged In",
            .adapter, "powernap", onOff, stock: "on"
        ),
        power(
            "power.adapter.network-wake", "Wake for network access",
            "Let other devices wake this Mac to reach shared files and services.", "Plugged In",
            .adapter, "womp", onOff, stock: "on"
        ),

        // Sleep
        power(
            "power.energy-mode", "Energy mode",
            "High Power runs the fans harder for demanding work. Only some Macs have it.", "Sleep and Performance",
            .everywhere, "powermode",
            [("automatic", "Automatic", "0"), ("low", "Low Power", "1"), ("high", "High Power", "2")],
            stock: "automatic"
        ),
        power(
            "power.standby", "Deep sleep",
            "Save more power after the Mac has been asleep for a while.", "Sleep and Performance",
            .everywhere, "standby", onOff, stock: "on",
            caution: "With this off, a sleeping laptop loses charge faster."
        ),
        power(
            "power.hibernate", "Save memory to disk when sleeping",
            "A copy on disk survives a flat battery. Always makes waking slower.", "Sleep and Performance",
            .everywhere, "hibernatemode",
            [("never", "Never", "0"), ("backup", "As a Backup", "3"), ("always", "Always", "25")],
            stock: "backup",
            caution: "Never loses unsaved work if the battery runs out during sleep. Apple advises leaving this alone."
        ),
        power(
            "power.keep-connections", "Stay connected during sleep",
            "Keep network connections open so Find My and notifications work.", "Sleep and Performance",
            .everywhere, "tcpkeepalive", onOff, stock: "on",
            caution: "With this off, Find My can't reach the Mac while it sleeps."
        ),
        power(
            "power.remote-sessions", "Stay awake for remote sessions",
            "Don't sleep while someone is signed in over the network.", "Sleep and Performance",
            .everywhere, "ttyskeepawake", onOff, stock: "on"
        ),
        power(
            "power.disk-sleep", "Put hard disks to sleep",
            "Spin down hard disks when they're idle. No effect on solid-state storage.", "Sleep and Performance",
            .everywhere, "disksleep", [("never", "Never", "0"), ("1", "After 1 Minute", "1"), ("on", "When Possible", "10")], stock: "on"
        ),
        power(
            "power.restart-after-failure", "Start up after a power failure",
            "Turn back on by itself when power returns.", "Sleep and Performance",
            .everywhere, "autorestart", onOff, stock: "off"
        ),
        Tweak(
            id: "power.lid-closed", title: "Stay awake with the lid closed",
            summary: "Keep running when the lid is shut, without a display attached.",
            category: .power, section: "Sleep and Performance",
            options: TweakOption.toggle,
            stock: "off",
            mechanism: .privileged(PrivilegedSetting(
                storage: "Power Management (pmset disablesleep)",
                probe: Probe(Command("/usr/sbin/ioreg", "-rd1", "-c", "IOPMrootDomain"), [
                    .init("on", #""SleepDisabled" = Yes"#, example: #""SleepDisabled" = Yes"#),
                    .init("off", #""SleepDisabled" = No"#, example: #""SleepDisabled" = No"#),
                ]),
                commands: [
                    "on": [Command(pmset, "-a", "disablesleep", "1")],
                    "off": [Command(pmset, "-a", "disablesleep", "0")],
                ],
                isHardwareDependent: true
            )),
            caution: "The Mac never sleeps at all while this is on. A closed laptop in a bag can overheat and will run its battery flat.",
            requiresBattery: true
        ),
        .toggle(
            "appearance.app-nap", "App Nap",
            "Slow down apps you can't see to save energy.",
            in: .power, "Sleep and Performance", .global, "NSAppSleepDisabled", stock: true,
            on: .bool(false), off: .bool(true), effect: .appRelaunch
        ),
    ]
}
