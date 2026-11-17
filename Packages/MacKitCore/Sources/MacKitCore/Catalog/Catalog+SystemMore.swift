import Foundation

private let loginWindow = PreferenceDomain.system("/Library/Preferences/com.apple.loginwindow")
private let softwareUpdate = PreferenceDomain.system("/Library/Preferences/com.apple.SoftwareUpdate")
private let launchctl = "/bin/launchctl"
private let sysadminctl = "/usr/sbin/sysadminctl"

extension Catalog {
    /// An on/off setting read with one command and changed with one command
    /// per state.
    static func switched(
        _ id: Tweak.ID, _ title: String, _ summary: String,
        in category: TweakCategory, _ section: String,
        storage: String,
        read: Command, on: String, off: String, examples: (on: String, off: String),
        turnOn: [Command], turnOff: [Command],
        stock: Bool, effect: Effect = .immediate, caution: String? = nil
    ) -> Tweak {
        Tweak(
            id: id, title: title, summary: summary, category: category, section: section,
            options: TweakOption.toggle,
            stock: stock ? "on" : "off",
            mechanism: .privileged(PrivilegedSetting(
                storage: storage,
                probe: Probe(read, [
                    .init("on", on, example: examples.on),
                    .init("off", off, example: examples.off),
                ]),
                commands: ["on": turnOn, "off": turnOff]
            )),
            effect: effect,
            caution: caution
        )
    }

    /// A sharing service that macOS runs as a system daemon.
    private static func service(
        _ id: Tweak.ID, _ title: String, _ summary: String, label: String, plist: String, caution: String
    ) -> Tweak {
        var stop = Command(launchctl, "bootout", "system/\(label)")
        stop.toleratesFailure = true
        var start = Command(launchctl, "bootstrap", "system", "/System/Library/LaunchDaemons/\(plist).plist")
        start.toleratesFailure = true
        return switched(
            id, title, summary, in: .sharing, "Sharing",
            storage: "System service \(label)",
            read: Command(launchctl, "print-disabled", "system"),
            // A service that has never been turned on isn't listed at all.
            on: #""\#(label)" => enabled"#, off: ".",
            examples: (on: #""\#(label)" => enabled"#, off: #""\#(label)" => disabled"#),
            turnOn: [Command(launchctl, "enable", "system/\(label)"), start],
            turnOff: [stop, Command(launchctl, "disable", "system/\(label)")],
            stock: false, caution: caution
        )
    }

    // MARK: Startup and login

    static let startupAndLogin: [Tweak] = [
        Tweak(
            id: "startup.auto-boot", title: "Turn on automatically",
            summary: "When a Mac laptop starts up by itself.",
            category: .system, section: "Startup",
            options: [
                TweakOption("both", "Opening the Lid or Connecting Power"), TweakOption("lid", "Opening the Lid"),
                TweakOption("power", "Connecting Power"), TweakOption("never", "Never"),
            ],
            stock: "both",
            // The variable is absent until the setting is changed.
            mechanism: .privileged(PrivilegedSetting(
                storage: "NVRAM BootPreference",
                probe: Probe(Command("/usr/sbin/nvram", "BootPreference"), [
                    .init("never", #"BootPreference\s+%00"#, example: "BootPreference\t%00"),
                    .init("power", #"BootPreference\s+%01"#, example: "BootPreference\t%01"),
                    .init("lid", #"BootPreference\s+%02"#, example: "BootPreference\t%02"),
                ], onFailure: "both"),
                commands: [
                    "both": [Command(executable: "/usr/sbin/nvram", arguments: ["-d", "BootPreference"], toleratesFailure: true)],
                    "lid": [Command("/usr/sbin/nvram", "BootPreference=%02")],
                    "power": [Command("/usr/sbin/nvram", "BootPreference=%01")],
                    "never": [Command("/usr/sbin/nvram", "BootPreference=%00")],
                ],
                isHardwareDependent: true
            )),
            effect: .nextStartup,
            requiresBattery: true
        ),

        // Login window
        .choice(
            "login.display", "Login window shows",
            "Pick from a list of accounts, or type a name and password.",
            in: .system, "Login Window", loginWindow, "SHOWFULLNAME",
            [("list", "List of Users", .bool(false)), ("name", "Name and Password", .bool(true))],
            stock: "list", effect: .logout
        ),
        .toggle(
            "login.power-buttons", "Sleep, Restart, and Shut Down buttons",
            "Show the power buttons on the login window.",
            in: .system, "Login Window", loginWindow, "PowerOffDisabled", stock: true,
            on: .bool(false), off: .bool(true), effect: .logout
        ),
        .toggle(
            "login.input-menu", "Input menu at login",
            "Let people choose a keyboard layout before logging in.",
            in: .system, "Login Window", loginWindow, "showInputMenu", stock: false, effect: .logout
        ),
        .choice(
            "login.password-hints", "Password hints",
            "Offer the hint after a few wrong passwords.",
            in: .system, "Login Window", loginWindow, "RetriesUntilHint",
            [("off", "Never", .int(0)), ("3", "After 3 Tries", .int(3))],
            stock: "off", effect: .logout
        ),
        .toggle(
            "login.console", "Allow console login",
            "Typing >console as the name opens a text-only login.",
            in: .system, "Login Window", loginWindow, "DisableConsoleAccess", stock: true,
            on: .bool(false), off: .bool(true), effect: .logout
        ),
        .toggle(
            "login.fast-switching", "Fast user switching",
            "Switch accounts without logging out.",
            in: .system, "Login Window", .system("/Library/Preferences/.GlobalPreferences"), "MultipleSessionEnabled",
            stock: true, effect: .logout
        ),
        .toggle(
            "login.reopen-windows", "Reopen windows when logging back in",
            "Bring back your apps and windows after a restart.",
            in: .system, "Login Window", .app("com.apple.loginwindow"), "TALLogoutSavesState", stock: true, effect: .logout
        ),

        // Date and time
        switched(
            "time.automatic", "Set date and time automatically",
            "Keep the clock right using a time server.",
            in: .system, "Date and Time",
            storage: "Date & Time",
            read: Command(sysadminctl, "-automaticTime", "status"),
            on: "Automatic time enabled", off: "Automatic time disabled",
            examples: (on: "sysadminctl[1:1] Automatic time enabled", off: "sysadminctl[1:1] Automatic time disabled"),
            turnOn: [Command(sysadminctl, "-automaticTime", "on")],
            turnOff: [Command(sysadminctl, "-automaticTime", "off")],
            stock: true,
            caution: "With this off the clock drifts, which breaks sign-ins and two-factor codes."
        ),
        .toggle(
            "time.zone", "Set time zone automatically",
            "Use your location to pick the time zone.",
            in: .system, "Date and Time", .system("/Library/Preferences/com.apple.timezone.auto"), "Active",
            stock: true, effect: .restart
        ),

        // Search
        switched(
            "spotlight.indexing", "Spotlight indexing",
            "Keep the index that makes search instant.",
            in: .system, "Search",
            storage: "Spotlight (mdutil)",
            read: Command("/usr/bin/mdutil", "-s", "/"),
            on: "Indexing enabled", off: "disabled",
            examples: (on: "/:\n\tIndexing enabled.", off: "/:\n\tIndexing disabled."),
            turnOn: [Command("/usr/bin/mdutil", "-a", "-i", "on")],
            turnOff: [Command("/usr/bin/mdutil", "-a", "-i", "off")],
            stock: true,
            caution: "With indexing off, Spotlight, Finder search, and Mail search stop finding things. Turning it back on rebuilds the index, which takes a while."
        ),
        switched(
            "backup.full-speed", "Full-speed backups",
            "Let Time Machine and other background work use the disk at full speed.",
            in: .power, "Sleep and Performance",
            storage: "Kernel setting debug.lowpri_throttle_enabled",
            read: Command("/usr/sbin/sysctl", "-n", "debug.lowpri_throttle_enabled"),
            on: "^0", off: "^1", examples: (on: "0", off: "1"),
            turnOn: [Command("/usr/sbin/sysctl", "debug.lowpri_throttle_enabled=0")],
            turnOff: [Command("/usr/sbin/sysctl", "debug.lowpri_throttle_enabled=1")],
            stock: false,
            caution: "Goes back to off whenever the Mac restarts. While on, the Mac can feel slower during a backup."
        ),
    ]

    // MARK: Software update

    static let updates: [Tweak] = [
        .toggle(
            "updates.check", "Check for updates",
            "Look for new software in the background.",
            in: .updates, "macOS", softwareUpdate, "AutomaticCheckEnabled", stock: true,
            caution: "With this off, security updates are never offered on their own."
        ),
        .toggle(
            "updates.download", "Download updates when available",
            "Fetch updates ahead of time so they're ready to install.",
            in: .updates, "macOS", softwareUpdate, "AutomaticDownload", stock: true
        ),
        .toggle(
            "updates.install-macos", "Install macOS updates",
            "Install new versions of macOS without asking.",
            in: .updates, "macOS", softwareUpdate, "AutomaticallyInstallMacOSUpdates", stock: true
        ),
        .toggle(
            "updates.security-responses", "Install Security Responses and system files",
            "Urgent security fixes that arrive between macOS updates.",
            in: .updates, "Security", softwareUpdate, "CriticalUpdateInstall", stock: true,
            caution: "With this off, the Mac misses urgent security fixes."
        ),
        .toggle(
            "updates.system-data", "Install system data files",
            "The lists macOS uses to recognize malware.",
            in: .updates, "Security", softwareUpdate, "ConfigDataInstall", stock: true,
            caution: "With this off, malware protection stops learning about new threats."
        ),
        .toggle(
            "updates.app-store", "Install App Store updates",
            "Keep App Store apps up to date without asking.",
            in: .updates, "Apps", .system("/Library/Preferences/com.apple.commerce"), "AutoUpdate", stock: true
        ),
    ]

    // MARK: Sharing and network

    static let sharing: [Tweak] = [
        service(
            "sharing.ssh", "Remote Login",
            "Let people sign in to this Mac from Terminal on another computer.",
            label: "com.openssh.sshd", plist: "ssh",
            caution: "Anyone on the network who knows an account password can sign in."
        ),
        service(
            "sharing.screen", "Screen Sharing",
            "Let people see and control this Mac's screen from another computer.",
            label: "com.apple.screensharing", plist: "com.apple.screensharing",
            caution: "Anyone on the network who knows an account password can see and control the screen."
        ),
        service(
            "sharing.files", "File Sharing",
            "Let other computers open this Mac's shared folders.",
            label: "com.apple.smbd", plist: "com.apple.smbd",
            caution: "Your Public folder becomes reachable from the network."
        ),
        service(
            "sharing.apple-events", "Remote Application Scripting",
            "Let apps on other Macs send commands to apps on this one.",
            label: "com.apple.AEServer", plist: "com.apple.eppc",
            caution: "People with an account on this Mac can run scripts on it from the network."
        ),
        switched(
            "sharing.printers", "Printer Sharing",
            "Let other computers print to this Mac's printers.",
            in: .sharing, "Sharing",
            storage: "Printing system (cupsctl)",
            read: Command("/usr/sbin/cupsctl"),
            on: "_share_printers=1", off: "_share_printers=0",
            examples: (on: "_share_printers=1", off: "_share_printers=0"),
            turnOn: [Command("/usr/sbin/cupsctl", "--share-printers")],
            turnOff: [Command("/usr/sbin/cupsctl", "--no-share-printers")],
            stock: false
        ),
        switched(
            "sharing.content-caching", "Content Caching",
            "Keep copies of Apple updates so other devices at home download them faster.",
            in: .sharing, "Sharing",
            storage: "Content Caching",
            read: Command("/usr/bin/AssetCacheManagerUtil", "status"),
            on: "Activated: true", off: "Activated: false",
            examples: (on: "Activated: true", off: "Activated: false"),
            turnOn: [Command("/usr/bin/AssetCacheManagerUtil", "activate")],
            turnOff: [Command("/usr/bin/AssetCacheManagerUtil", "deactivate")],
            stock: false,
            caution: "Uses disk space and network bandwidth for the copies."
        ),
        switched(
            "sharing.guest-files", "Guests can open shared folders",
            "Let people connect to shared folders without a password.",
            in: .sharing, "Sharing",
            storage: "File Sharing guest access",
            read: Command(sysadminctl, "-smbGuestAccess", "status"),
            on: "SMB guest access enabled", off: "SMB guest access disabled",
            examples: (on: "sysadminctl[1:1] SMB guest access enabled", off: "sysadminctl[1:1] SMB guest access disabled"),
            turnOn: [Command(sysadminctl, "-smbGuestAccess", "on")],
            turnOff: [Command(sysadminctl, "-smbGuestAccess", "off")],
            stock: true
        ),

        // Network
        .toggle(
            "network.bonjour", "Announce this Mac on the network",
            "Lets other devices find it for AirPlay, printing, and file sharing.",
            in: .sharing, "Network", .system("/Library/Preferences/com.apple.mDNSResponder"), "NoMulticastAdvertisements",
            stock: true, on: .bool(false), off: .bool(true), effect: .restart,
            caution: "With this off, other devices can't find this Mac by name."
        ),
        .toggle(
            "network.captive-portal", "Wi-Fi sign-in window",
            "Pop up the sign-in page for hotel and café Wi-Fi.",
            in: .sharing, "Network", .system("/Library/Preferences/SystemConfiguration/com.apple.captive.control"), "Active",
            stock: true, effect: .restart,
            caution: "With this off you have to open a browser yourself to sign in to public Wi-Fi."
        ),
    ]

    // MARK: Privacy and security

    private static let diagnostics = "/Library/Application Support/CrashReporter/DiagnosticMessagesHistory.plist"
    private static let sudoLocal = "/etc/pam.d/sudo_local"

    private static func analytics(_ id: Tweak.ID, _ title: String, _ summary: String, key: String, stock: Bool) -> Tweak {
        switched(
            id, title, summary, in: .security, "Analytics",
            storage: "Diagnostics settings (\(key))",
            read: Command("/usr/bin/defaults", "read", diagnostics, key),
            on: "^1", off: "^0", examples: (on: "1", off: "0"),
            // Writing as root leaves the file unreadable to the system
            // service that needs it, so put its permissions back.
            turnOn: [Command("/usr/bin/defaults", "write", diagnostics, key, "-bool", "true"), Command("/bin/chmod", "644", diagnostics)],
            turnOff: [Command("/usr/bin/defaults", "write", diagnostics, key, "-bool", "false"), Command("/bin/chmod", "644", diagnostics)],
            stock: stock
        )
    }

    static let securityMore: [Tweak] = [
        switched(
            "security.block-all", "Block all incoming connections",
            "Refuse everything except what basic internet service needs.",
            in: .security, "Network",
            storage: "Application Firewall",
            read: Command(firewallTool, "--getblockall"),
            on: "block all state set to enabled|block all incoming", off: "disabled",
            examples: (on: "Firewall has block all state set to enabled.", off: "Firewall has block all state set to disabled."),
            turnOn: [Command(firewallTool, "--setblockall", "on")],
            turnOff: [Command(firewallTool, "--setblockall", "off")],
            stock: false,
            caution: "Stops file sharing, screen sharing, and AirPlay to this Mac. Only matters while the firewall is on."
        ),
        switched(
            "security.allow-built-in", "Allow built-in software",
            "Let Apple's own apps and services accept connections without asking.",
            in: .security, "Network",
            storage: "Application Firewall",
            read: Command(firewallTool, "--getallowsigned"),
            on: "built-in signed software ENABLED", off: "built-in signed software DISABLED",
            examples: (
                on: "Automatically allow built-in signed software ENABLED",
                off: "Automatically allow built-in signed software DISABLED"
            ),
            turnOn: [Command(firewallTool, "--setallowsigned", "on")],
            turnOff: [Command(firewallTool, "--setallowsigned", "off")],
            stock: true
        ),
        switched(
            "security.allow-signed", "Allow downloaded signed software",
            "Let apps from identified developers accept connections without asking.",
            in: .security, "Network",
            storage: "Application Firewall",
            read: Command(firewallTool, "--getallowsigned"),
            on: "downloaded signed software ENABLED", off: "downloaded signed software DISABLED",
            examples: (
                on: "Automatically allow downloaded signed software ENABLED",
                off: "Automatically allow downloaded signed software DISABLED"
            ),
            turnOn: [Command(firewallTool, "--setallowsignedapp", "on")],
            turnOff: [Command(firewallTool, "--setallowsignedapp", "off")],
            stock: true
        ),
        .toggle(
            "security.guest", "Guest user",
            "Let anyone use this Mac without a password. Their files are erased at logout.",
            in: .security, "Accounts", loginWindow, "GuestEnabled", stock: false, effect: .logout,
            caution: "A guest can use your network and any shared folders."
        ),
        Tweak(
            id: "security.touch-id-sudo", title: "Touch ID for sudo",
            summary: "Approve administrator commands in Terminal with your fingerprint.",
            category: .security, section: "Accounts",
            options: TweakOption.toggle,
            stock: "off",
            mechanism: .privileged(PrivilegedSetting(
                storage: sudoLocal,
                // Counts the lines that turn Touch ID on. `grep` fails when
                // there are none, or when the file doesn't exist yet.
                probe: Probe(
                    Command("/usr/bin/grep", "-cE", #"^auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so"#, sudoLocal),
                    [.init("on", "^[1-9]", example: "1")],
                    onFailure: "off"
                ),
                commands: [
                    // Start from Apple's template if the file is missing,
                    // uncomment its Touch ID line, and add the line on its
                    // own newline if the file had none. Keep mode 0444 so
                    // OpenPAM never rejects the file.
                    "on": [Command("/bin/sh", "-c", """
                    LC_ALL=C; \
                    [ -f \(sudoLocal) ] || [ ! -f \(sudoLocal).template ] || /bin/cp \(sudoLocal).template \(sudoLocal); \
                    [ ! -f \(sudoLocal) ] || /usr/bin/sed -i '' -E 's/^#[[:space:]]*(auth[[:space:]]+sufficient[[:space:]]+pam_tid\\.so)/\\1/' \(sudoLocal); \
                    if ! /usr/bin/grep -qE '^auth[[:space:]]+sufficient[[:space:]]+pam_tid\\.so' \(sudoLocal) 2>/dev/null; then \
                    [ ! -s \(sudoLocal) ] || /usr/bin/tail -c 1 \(sudoLocal) | /usr/bin/grep -q '^$' || /usr/bin/printf '\\n' >> \(sudoLocal); \
                    /usr/bin/printf 'auth       sufficient     pam_tid.so\\n' >> \(sudoLocal); \
                    fi; \
                    /bin/chmod 444 \(sudoLocal)
                    """)],
                    "off": [Command("/bin/sh", "-c", """
                    LC_ALL=C; \
                    [ ! -f \(sudoLocal) ] || { /usr/bin/sed -i '' -E 's/^(auth[[:space:]]+sufficient[[:space:]]+pam_tid\\.so)/#\\1/' \(sudoLocal) && /bin/chmod 444 \(sudoLocal); }
                    """)],
                ]
            ))
        ),
        analytics(
            "privacy.analytics", "Share Mac Analytics",
            "Send Apple diagnostic and usage data from this Mac.",
            key: "AutoSubmit", stock: false
        ),
        analytics(
            "privacy.crash-data", "Share with app developers",
            "Send crash and usage data to the makers of your apps.",
            key: "ThirdPartyDataSubmit", stock: false
        ),
    ]
}
