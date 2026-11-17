import Foundation

extension Catalog {
    // MARK: Security

    static let firewallTool = "/usr/libexec/ApplicationFirewall/socketfilterfw"

    static let security: [Tweak] = [
        Tweak(
            id: "security.firewall", title: "Firewall",
            summary: "Block unwanted incoming connections.",
            category: .security, section: "Network",
            options: TweakOption.toggle,
            stock: "off",
            mechanism: .privileged(PrivilegedSetting(
                storage: "Application Firewall",
                probe: Probe(Command(firewallTool, "--getglobalstate"), [
                    .init("off", #"State = 0|disabled"#, example: "Firewall is disabled. (State = 0)"),
                    .init("on", #"State = [12]|enabled"#, example: "Firewall is enabled. (State = 1)"),
                ]),
                commands: [
                    "on": [Command(firewallTool, "--setglobalstate", "on")],
                    "off": [Command(firewallTool, "--setglobalstate", "off")],
                ]
            ))
        ),
        Tweak(
            id: "security.stealth", title: "Stealth mode",
            summary: "Don't answer network probes like ping.",
            category: .security, section: "Network",
            options: TweakOption.toggle,
            stock: "off",
            mechanism: .privileged(PrivilegedSetting(
                storage: "Application Firewall",
                probe: Probe(Command(firewallTool, "--getstealthmode"), [
                    .init("off", #"stealth mode is off|stealth mode disabled"#, example: "Firewall stealth mode is off"),
                    .init("on", #"stealth mode is on|stealth mode enabled"#, example: "Firewall stealth mode is on"),
                ]),
                commands: [
                    "on": [Command(firewallTool, "--setstealthmode", "on")],
                    "off": [Command(firewallTool, "--setstealthmode", "off")],
                ]
            ))
        ),
        Tweak(
            id: "startup.chime", title: "Startup sound",
            summary: "Play the chime when this Mac starts.",
            category: .system, section: "Startup",
            options: TweakOption.toggle,
            stock: "on",
            // The variable is absent on a Mac that has never changed the
            // setting, and `nvram` exits with an error. That means the chime
            // plays.
            mechanism: .privileged(PrivilegedSetting(
                storage: "NVRAM StartupMute",
                probe: Probe(Command("/usr/sbin/nvram", "StartupMute"), [
                    .init("off", #"StartupMute\s+%01"#, example: "StartupMute\t%01"),
                    .init("on", #"StartupMute"#, example: "StartupMute\t%00"),
                ], onFailure: "on"),
                commands: [
                    "on": [Command("/usr/sbin/nvram", "StartupMute=%00")],
                    "off": [Command("/usr/sbin/nvram", "StartupMute=%01")],
                ]
            )),
            effect: .nextStartup
        ),
    ]
}
