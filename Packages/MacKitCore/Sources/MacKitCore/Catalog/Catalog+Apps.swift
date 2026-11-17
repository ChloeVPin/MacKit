import Foundation

extension Catalog {
    private static func app(_ id: String) -> PreferenceDomain { .app(id) }

    // MARK: Screenshots

    static let screenshotsMore: [Tweak] = [
        .choice(
            "screenshot.destination", "After capturing",
            "What happens to a new screenshot.",
            in: .screenshots, "Saving", .app("com.apple.screencapture"), "target-screenshot",
            [
                ("file", "Save to the Folder", .string("file")), ("clipboard", "Copy to Clipboard", .string("clipboard")),
                ("preview", "Open in Preview", .string("preview")), ("mail", "New Mail Message", .string("mail")),
                ("messages", "New Message", .string("messages")),
            ],
            stock: "file", effect: .restarts(.systemUIServer)
        ),
        .toggle(
            "screenshot.date", "Date and time in the name",
            "Turn off for short names like Screenshot 1, Screenshot 2.",
            in: .screenshots, "Saving", .app("com.apple.screencapture"), "include-date", stock: true,
            effect: .restarts(.systemUIServer)
        ),
        .toggle(
            "screenshot.pointer", "Show the pointer",
            "Include the mouse pointer in captures.",
            in: .screenshots, "Appearance", .app("com.apple.screencapture"), "showsCursor", stock: false,
            effect: .restarts(.systemUIServer)
        ),
        .toggle(
            "screenshot.clicks", "Show clicks in recordings",
            "Draw a circle around each click in a screen recording.",
            in: .screenshots, "Appearance", .app("com.apple.screencapture"), "showsClicks", stock: false,
            effect: .restarts(.systemUIServer)
        ),
        .toggle(
            "screenshot.remember-selection", "Remember the last selection",
            "Start from the area you captured last time.",
            in: .screenshots, "Saving", .app("com.apple.screencapture"), "save-selections", stock: true,
            effect: .restarts(.systemUIServer)
        ),
    ]

    // MARK: Apps

    static let apps: [Tweak] = safari + textEdit + terminal + activityMonitor + calendar + otherApps + xcode

    private static let safari: [Tweak] = {
        let d = app("com.apple.Safari")
        func t(_ id: String, _ title: String, _ summary: String, _ key: String, stock: Bool,
               on: PreferenceValue = .bool(true), off: PreferenceValue = .bool(false), caution: String? = nil) -> Tweak {
            .toggle("safari.\(id)", title, summary, in: .apps, "Safari", d, key, stock: stock, on: on, off: off, effect: .appRelaunch, caution: caution)
        }
        let pages: [(id: TweakOption.ID, label: String, value: PreferenceValue)] = [
            ("start", "Start Page", .int(4)), ("home", "Homepage", .int(0)), ("empty", "Empty Page", .int(1)),
            ("same", "Same Page", .int(2)), ("bookmarks", "Bookmarks", .int(3)),
        ]
        return [
            t("full-url", "Show full website address", "Show the whole address, not just the site name.", "ShowFullURLInSmartSearchField", stock: false),
            t("status-bar", "Status bar", "Show where a link goes when you point at it.", "ShowOverlayStatusBar", stock: false),
            t("favorites-bar", "Favorites bar", "A row of your favorite sites under the address bar.", "ShowFavoritesBar-v2", stock: false),
            .choice("safari.tab-layout", "Tab layout", "Tabs in their own row, or merged into the address bar.",
                    in: .apps, "Safari", d, "ShowStandaloneTabBar",
                    [("separate", "Separate", .bool(true)), ("compact", "Compact", .bool(false))], stock: "separate", effect: .appRelaunch),
            t("toolbar-color", "Color in the tab bar", "Let websites tint the top of the window.", "NeverUseBackgroundColorInToolbar", stock: true, on: .bool(false), off: .bool(true)),
            .choice("safari.new-window", "New windows open with", "What a new Safari window shows.",
                    in: .apps, "Safari", d, "NewWindowBehavior", pages, stock: "start", effect: .appRelaunch),
            .choice("safari.new-tab", "New tabs open with", "What a new Safari tab shows.",
                    in: .apps, "Safari", d, "NewTabBehavior", pages, stock: "start", effect: .appRelaunch),
            t("restore-session", "Reopen windows at launch", "Start with the windows and tabs from last time.", "AlwaysRestoreSessionAtLaunch", stock: false),
            .choice("safari.tabs-policy", "Open pages in tabs", "When a link asks for a new window, open a tab instead.",
                    in: .apps, "Safari", d, "TabCreationPolicy",
                    [("never", "Never", .int(0)), ("automatically", "Automatically", .int(1)), ("always", "Always", .int(2))],
                    stock: "automatically", effect: .appRelaunch),
            t("new-tabs-front", "Switch to new tabs", "Bring a new tab forward as soon as it opens.", "OpenNewTabsInFront", stock: false),
            t("command-click-tabs", "Command-click opens a tab", "Turn off to open a new window instead.", "CommandClickMakesTabs", stock: true),
            t("tab-key-links", "Tab key reaches every link", "Press Tab to move through links as well as form fields.", "WebKitTabToLinksPreferenceKey", stock: false),
            t("open-safe-downloads", "Open safe files after downloading", "Open PDFs, images, and archives as soon as they arrive.", "AutoOpenSafeDownloads", stock: true),
            .choice("safari.clear-downloads", "Remove download list items", "When finished downloads leave the list. The files stay.",
                    in: .apps, "Safari", d, "DownloadsClearingPolicy",
                    [("day", "After One Day", .int(3)), ("quit", "When Safari Quits", .int(1)),
                     ("done", "When Downloaded", .int(2)), ("manual", "Manually", .int(0))],
                    stock: "day", effect: .appRelaunch),
            .choice("safari.history", "Keep history for", "How long Safari remembers the pages you visited.",
                    in: .apps, "Safari", d, "HistoryAgeInDaysLimit",
                    [("day", "One Day", .int(1)), ("week", "One Week", .int(7)), ("two-weeks", "Two Weeks", .int(14)),
                     ("month", "One Month", .int(31)), ("year", "One Year", .int(365)), ("forever", "Forever", .int(365_000))],
                    stock: "year", effect: .appRelaunch),
            t("search-suggestions", "Search engine suggestions", "Suggest searches as you type in the address bar.", "SuppressSearchSuggestions", stock: true, on: .bool(false), off: .bool(true)),
            t("safari-suggestions", "Safari Suggestions", "Show answers from Apple as you type, such as weather and stocks.", "UniversalSearchEnabled", stock: true),
            t("preload-top-hit", "Preload the top hit", "Start loading the best match before you press Return.", "PreloadTopHit", stock: true),
            t("quick-website-search", "Quick Website Search", "Search inside a site by typing its name, then your search.", "WebsiteSpecificSearchEnabled", stock: true),
            t("find-anywhere", "Find matches inside words", "Find on Page matches anywhere, not only at the start of a word.", "FindOnPageMatchesWordStartsOnly", stock: false, on: .bool(false), off: .bool(true)),
            t("autofill-contacts", "AutoFill contact info", "Fill in your name and address from Contacts.", "AutoFillFromAddressBook", stock: true),
            t("autofill-passwords", "AutoFill passwords", "Fill in saved user names and passwords.", "AutoFillPasswords", stock: true),
            t("autofill-cards", "AutoFill credit cards", "Fill in saved payment cards.", "AutoFillCreditCardData", stock: true),
            t("autofill-forms", "AutoFill other forms", "Remember what you typed into other web forms.", "AutoFillMiscellaneousForms", stock: true),
            t("fraud-warning", "Fraudulent website warning", "Warn before opening a site known for scams or malware.", "WarnAboutFraudulentWebsites", stock: true,
              caution: "With this off, Safari no longer warns about known scam sites."),
            t("private-lock", "Lock Private Browsing", "Ask for Touch ID or your password to see private windows.", "PrivateBrowsingRequiresAuthentication", stock: false),
            t("tracking-all", "Advanced tracking protection everywhere", "Use the stricter protection in every window, not only private ones.", "EnableEnhancedPrivacyInRegularBrowsing", stock: false),
            t("notification-prompts", "Websites can ask to send notifications", "Let websites ask to send notifications, or silence every prompt.", "CanPromptForPushNotifications", stock: true),
            t("spelling", "Check spelling in web forms", "Underline misspelled words as you type on websites.", "WebContinuousSpellCheckingEnabled", stock: true),
            t("autocorrect", "Correct spelling in web forms", "Fix misspelled words as you type on websites.", "WebAutomaticSpellingCorrectionEnabled", stock: true),
            Tweak(
                id: "safari.develop", title: "Develop menu",
                summary: "Tools for web developers, including Web Inspector.",
                category: .apps, section: "Safari", options: TweakOption.toggle, stock: "off",
                mechanism: .preferences([
                    PreferenceBinding(d, "IncludeDevelopMenu", ["on": .bool(true), "off": .bool(false)], isOptionalOnRead: true),
                    PreferenceBinding(d, "WebKitDeveloperExtrasEnabledPreferenceKey", ["on": .bool(true), "off": .bool(false)], isOptionalOnRead: true),
                    PreferenceBinding(d, "WebKitPreferences.developerExtrasEnabled", ["on": .bool(true), "off": .bool(false)], isOptionalOnRead: true),
                ]),
                effect: .appRelaunch
            ),
        ]
    }()

    private static let textEdit: [Tweak] = {
        let d = app("com.apple.TextEdit")
        func t(_ id: String, _ title: String, _ summary: String, _ key: String, stock: Bool) -> Tweak {
            .toggle("textedit.\(id)", title, summary, in: .apps, "TextEdit", d, key, stock: stock, effect: .appRelaunch)
        }
        let encodings: [(id: TweakOption.ID, label: String, value: PreferenceValue)] = [
            ("automatic", "Automatic", .int(0)), ("utf8", "UTF-8", .int(4)), ("utf16", "UTF-16", .int(10)),
            ("latin1", "Western (ISO Latin 1)", .int(5)), ("mac-roman", "Western (Mac OS Roman)", .int(30)),
        ]
        return [
            .choice("textedit.format", "New documents are", "The format a new TextEdit document starts in.",
                    in: .apps, "TextEdit", d, "RichText",
                    [("rich", "Rich Text", .bool(true)), ("plain", "Plain Text", .bool(false))], stock: "rich", effect: .appRelaunch),
            .choice("textedit.open-encoding", "Open plain text as", "The text encoding assumed when opening files.",
                    in: .apps, "TextEdit", d, "PlainTextEncoding", encodings, stock: "automatic", effect: .appRelaunch),
            .choice("textedit.save-encoding", "Save plain text as", "The text encoding used when saving files.",
                    in: .apps, "TextEdit", d, "PlainTextEncodingForWrite", encodings, stock: "automatic", effect: .appRelaunch),
            t("add-txt", "Add .txt to plain text files", "Give new plain text files the .txt ending.", "AddExtensionToNewPlainTextFiles", stock: true),
            t("html-as-code", "Show HTML files as code", "Open web pages as their source, not formatted.", "IgnoreHTML", stock: false),
            t("rtf-as-code", "Show RTF files as code", "Open rich text files as their source, not formatted.", "IgnoreRichText", stock: false),
            t("ruler", "Ruler", "Show the ruler at the top of rich text documents.", "ShowRuler", stock: true),
            t("wrap-to-page", "Wrap to page", "Lay text out as printed pages instead of filling the window.", "ShowPageBreaks", stock: false),
            .choice("textedit.tab-width", "Tab width", "How many spaces wide a tab is in plain text.",
                    in: .apps, "TextEdit", d, "TabWidth",
                    [("2", "2 Spaces", .int(2)), ("4", "4 Spaces", .int(4)), ("8", "8 Spaces", .int(8))], stock: "8", effect: .appRelaunch),
            .slider("textedit.font-size", "Plain text size", "The font size for plain text documents.",
                    in: .apps, "TextEdit", d, "NSFixedPitchFontSize",
                    NumberInput(9...36, step: 1, unit: " pt", isInteger: true), stock: 11, effect: .appRelaunch),
            t("spelling", "Check spelling as you type", "Underline misspelled words.", "CheckSpellingWhileTyping", stock: true),
            t("grammar", "Check grammar with spelling", "Underline grammar mistakes too.", "CheckGrammarWithSpelling", stock: false),
            t("autocorrect", "Correct spelling", "Fix misspelled words as you type.", "CorrectSpellingAutomatically", stock: true),
            t("smart-quotes", "Smart quotes", "Curl straight quotes in TextEdit.", "SmartQuotes", stock: true),
            t("smart-dashes", "Smart dashes", "Join two hyphens into a dash in TextEdit.", "SmartDashes", stock: true),
            t("smart-copy-paste", "Smart copy and paste", "Tidy the spaces around text you paste.", "SmartCopyPaste", stock: true),
            t("smart-links", "Smart links", "Turn web addresses into links as you type.", "SmartLinks", stock: false),
            t("data-detectors", "Data detectors", "Recognize dates and addresses in documents.", "DataDetectors", stock: false),
            t("text-replacement", "Text replacement", "Expand your shortcuts from Keyboard settings.", "TextReplacement", stock: true),
            t("rich-only", "Smart features in rich text only", "Leave plain text exactly as typed.", "SmartSubstitutionsEnabledInRichTextOnly", stock: true),
        ]
    }()

    private static let terminal: [Tweak] = {
        let d = app("com.apple.Terminal")
        return [
            .toggle("terminal.secure-entry", "Secure Keyboard Entry", "Stop other apps from seeing what you type in Terminal.",
                    in: .apps, "Terminal", d, "SecureKeyboardEntry", stock: false, effect: .appRelaunch),
            .toggle("terminal.focus-follows-mouse", "Focus follows the pointer", "Type into whichever Terminal window the pointer is over.",
                    in: .apps, "Terminal", d, "FocusFollowsMouse", stock: false, effect: .appRelaunch),
            .toggle("terminal.line-marks", "Line marks", "Show the brackets that mark each command.",
                    in: .apps, "Terminal", d, "ShowLineMarks", stock: true, effect: .appRelaunch),
            .toggle("terminal.auto-marks", "Mark each prompt", "Add a mark to every command line automatically.",
                    in: .apps, "Terminal", d, "AutoMarkPromptLines", stock: true, effect: .appRelaunch),
        ]
    }()

    private static let activityMonitor: [Tweak] = {
        let d = app("com.apple.ActivityMonitor")
        return [
            .choice("activity.update", "Update frequency", "How often the numbers refresh.",
                    in: .apps, "Activity Monitor", d, "UpdatePeriod",
                    [("5", "Normally", .int(5)), ("2", "Often", .int(2)), ("1", "Very Often", .int(1))], stock: "5", effect: .appRelaunch),
            .choice("activity.dock-icon", "Dock icon shows", "Turn the Dock icon into a live graph.",
                    in: .apps, "Activity Monitor", d, "IconType",
                    [("app", "App Icon", .int(0)), ("cpu", "CPU Usage", .int(5)), ("cpu-history", "CPU History", .int(6)),
                     ("network", "Network Usage", .int(2)), ("disk", "Disk Activity", .int(3))],
                    stock: "app", effect: .appRelaunch),
            .choice("activity.processes", "Show processes", "Which processes the list starts with.",
                    in: .apps, "Activity Monitor", d, "ShowCategory",
                    [("mine", "My Processes", .int(102)), ("all", "All Processes", .int(100)),
                     ("tree", "All, Hierarchically", .int(101)), ("system", "System Processes", .int(103)),
                     ("active", "Active Processes", .int(105)), ("windowed", "Windowed Processes", .int(107))],
                    stock: "mine", effect: .appRelaunch),
            .toggle("activity.open-window", "Open the main window at launch", "Turn off to start with just the Dock icon.",
                    in: .apps, "Activity Monitor", d, "OpenMainWindow", stock: true, effect: .appRelaunch),
            .choice("activity.disk-graph", "Disk graph shows", "What the disk graph measures.",
                    in: .apps, "Activity Monitor", d, "DiskGraphType",
                    [("io", "Operations", .int(0)), ("data", "Data", .int(1))], stock: "io", effect: .appRelaunch),
            .choice("activity.network-graph", "Network graph shows", "What the network graph measures.",
                    in: .apps, "Activity Monitor", d, "NetworkGraphType",
                    [("packets", "Packets", .int(0)), ("data", "Data", .int(1))], stock: "packets", effect: .appRelaunch),
        ]
    }()

    private static let calendar: [Tweak] = {
        let d = app("com.apple.iCal")
        func hour(_ h: Int) -> (id: TweakOption.ID, label: String, value: PreferenceValue) {
            ("\(h)", "\(h > 12 ? h - 12 : h):00 \(h < 12 ? "AM" : "PM")", .int(h * 60))
        }
        return [
            .toggle("calendar.week-numbers", "Week numbers", "Show the number of each week.",
                    in: .apps, "Calendar", d, "Show Week Numbers", stock: false, effect: .appRelaunch),
            .choice("calendar.days", "Days per week", "Show a full week or just weekdays.",
                    in: .apps, "Calendar", d, "n days of week", [("7", "7", .int(7)), ("5", "5", .int(5))], stock: "7", effect: .appRelaunch),
            .choice("calendar.day-start", "Day starts at", "Where the working day begins in Day and Week view.",
                    in: .apps, "Calendar", d, "first minute of work hours", [6, 7, 8, 9, 10].map(hour), stock: "8", effect: .appRelaunch),
            .choice("calendar.day-end", "Day ends at", "Where the working day ends in Day and Week view.",
                    in: .apps, "Calendar", d, "last minute of work hours", [16, 17, 18, 19, 20].map(hour), stock: "18", effect: .appRelaunch),
            .slider("calendar.hours-shown", "Hours shown at once", "How much of the day fits without scrolling.",
                    in: .apps, "Calendar", d, "number of hours displayed",
                    NumberInput(6...24, step: 2, unit: " hr", isInteger: true), stock: 12, effect: .appRelaunch),
            .choice("calendar.event-length", "New events last", "The default length of a new event.",
                    in: .apps, "Calendar", d, "Default duration in minutes for new event",
                    [("15", "15 Minutes", .int(15)), ("30", "30 Minutes", .int(30)), ("45", "45 Minutes", .int(45)),
                     ("60", "1 Hour", .int(60)), ("90", "1.5 Hours", .int(90))],
                    stock: "60", effect: .appRelaunch),
            .toggle("calendar.time-zones", "Time zone support", "Give events their own time zones.",
                    in: .apps, "Calendar", d, "TimeZone support enabled", stock: false, effect: .appRelaunch),
            .toggle("calendar.heat-map", "Year view heat map", "Color busier days more strongly in Year view.",
                    in: .apps, "Calendar", d, "Show heat map in Year View", stock: true, effect: .appRelaunch),
            .toggle("calendar.declined", "Show declined events", "Keep events you turned down on the calendar.",
                    in: .apps, "Calendar", d, "ShowDeclinedEvents", stock: false, effect: .appRelaunch),
            .toggle("calendar.invite-warning", "Ask before sending invitation changes", "Confirm before guests are emailed about a change.",
                    in: .apps, "Calendar", d, "WarnBeforeSendingInvitations", stock: false, effect: .appRelaunch),
        ]
    }()

    private static let otherApps: [Tweak] = [
        .toggle("diskutility.all-devices", "Show all devices", "List whole disks, not only their volumes.",
                in: .apps, "Disk Utility", app("com.apple.DiskUtility"), "SidebarShowAllDevices", stock: false, effect: .appRelaunch),
        .toggle("diskutility.snapshots", "Show APFS snapshots", "List the snapshots stored on each volume.",
                in: .apps, "Disk Utility", app("com.apple.DiskUtility"), "WorkspaceShowAPFSSnapshots", stock: false, effect: .appRelaunch),
        .toggle("timemachine.offer-disks", "Offer new disks for backup", "Ask whether to back up to a drive when you plug one in.",
                in: .apps, "Time Machine", app("com.apple.TimeMachine"), "DoNotOfferNewDisksForBackup", stock: true,
                on: .bool(false), off: .bool(true)),
        .toggle("photos.hot-plug", "Open Photos when a device connects", "Open Photos for a camera, iPhone, or memory card.",
                in: .apps, "Photos", .currentHost("com.apple.ImageCapture"), "disableHotPlug", stock: true,
                on: .bool(false), off: .bool(true)),
        .toggle("photos.autoplay", "Autoplay videos and Live Photos", "Play them as you browse your library.",
                in: .apps, "Photos", app("com.apple.Photos"), "IPXDefaultAutoplayVideos", stock: true, effect: .appRelaunch),
        .toggle("photos.holidays", "Show holiday events", "Name memories after public holidays.",
                in: .apps, "Photos", app("com.apple.Photos"), "showHolidayEvents", stock: true, effect: .appRelaunch),
        .toggle("music.notifications", "Song change notifications", "Show a notification when the song changes.",
                in: .apps, "Music", app("com.apple.Music"), "userWantsPlaybackNotifications", stock: true, effect: .appRelaunch),
        .toggle("messages.subject", "Subject field", "Add a subject line above each message you write.",
                in: .apps, "Messages", app("com.apple.MobileSMS"), "MMSShowSubject", stock: false, effect: .appRelaunch),
        .toggle("preview.restore", "Reopen documents in Preview", "Bring back the files you had open last time.",
                in: .apps, "Preview", app("com.apple.Preview"), "ApplePersistenceIgnoreState", stock: true,
                on: .bool(false), off: .bool(true), effect: .appRelaunch),
        .toggle("preview.sidebar", "PDF sidebar", "Show the page sidebar when a PDF opens.",
                in: .apps, "Preview", app("com.apple.Preview"), "PVPDFSuppressSidebarOnOpening", stock: true,
                on: .bool(false), off: .bool(true), effect: .appRelaunch),
        .toggle("preview.annotation-name", "Add your name to annotations", "Sign the notes and highlights you add to PDFs.",
                in: .apps, "Preview", app("com.apple.Preview"), "PVGeneralUseUserName", stock: true, effect: .appRelaunch),
        .choice("archive.format", "Archive format", "The kind of archive made by Compress.",
                in: .apps, "Archive Utility", app("com.apple.archiveutility"), "archive-format",
                [("zip", "ZIP", .string("zip")), ("cpgz", "Compressed Archive", .string("cpgz")), ("cpio", "Regular Archive", .string("cpio"))],
                stock: "zip"),
        .choice("archive.after-expanding", "After expanding", "What happens to an archive once it's opened.",
                in: .apps, "Archive Utility", app("com.apple.archiveutility"), "dearchive-move-after",
                [("keep", "Leave It Alone", .string(".")), ("trash", "Move It to the Trash", .string("~/.Trash"))], stock: "keep"),
        .choice("archive.after-compressing", "After compressing", "What happens to the originals once they're archived.",
                in: .apps, "Archive Utility", app("com.apple.archiveutility"), "archive-move-after",
                [("keep", "Leave Them Alone", .string(".")), ("trash", "Move Them to the Trash", .string("~/.Trash"))], stock: "keep"),
        .toggle("archive.reveal-expanded", "Reveal expanded items", "Show the result in Finder after expanding.",
                in: .apps, "Archive Utility", app("com.apple.archiveutility"), "dearchive-reveal-after", stock: false),
        .toggle("archive.reveal-archive", "Reveal new archives", "Show the archive in Finder after compressing.",
                in: .apps, "Archive Utility", app("com.apple.archiveutility"), "archive-reveal-after", stock: false),
        .toggle("archive.nested", "Keep expanding nested archives", "Open archives found inside an archive.",
                in: .apps, "Archive Utility", app("com.apple.archiveutility"), "dearchive-recursively", stock: true),
        .toggle("siri.listen", "Listen for “Siri”", "Start Siri by voice.",
                in: .apps, "Siri", app("com.apple.Siri"), "VoiceTriggerUserEnabled", stock: false, effect: .logout),
        .toggle("siri.type", "Type to Siri", "Type requests instead of speaking them.",
                in: .apps, "Siri", app("com.apple.Siri"), "TypeToSiriEnabled", stock: false, effect: .logout),
        .toggle("siri.locked", "Siri when locked", "Allow Siri while the screen is locked.",
                in: .apps, "Siri", app("com.apple.Siri"), "LockscreenEnabled", stock: true, effect: .logout),
    ]

    private static let xcode: [Tweak] = {
        let d = app("com.apple.dt.Xcode")
        func t(_ id: String, _ title: String, _ summary: String, _ key: String, stock: Bool, caution: String? = nil) -> Tweak {
            .toggle("xcode.\(id)", title, summary, in: .apps, "Xcode", d, key, stock: stock, effect: .appRelaunch, caution: caution)
        }
        return [
            t("build-duration", "Show build duration", "Show how long each build took in the toolbar.", "ShowBuildOperationDuration", stock: false),
            t("line-numbers", "Line numbers", "Number each line in the editor.", "DVTTextShowLineNumbers", stock: true),
            t("minimap", "Minimap", "A zoomed-out outline of the file at the side.", "DVTTextShowMinimap", stock: true),
            t("folding", "Code folding ribbon", "Fold blocks of code from the gutter.", "DVTTextShowFoldingSidebar", stock: false),
            t("invisibles", "Invisible characters", "Show spaces, tabs, and line endings.", "DVTTextShowInvisibleCharacters", stock: false),
            t("wrap", "Wrap lines", "Wrap long lines to the editor width.", "DVTTextEditorWrapsLines", stock: true),
            t("trim-trailing", "Trim trailing whitespace", "Remove spaces at the ends of lines you edit.", "DVTTextEditorTrimTrailingWhitespace", stock: true),
            t("trim-blank", "Trim whitespace-only lines", "Also empty lines that hold nothing but spaces.", "DVTTextEditorTrimWhitespaceOnlyLines", stock: false),
            t("tabs", "Indent using tabs", "Insert tab characters instead of spaces.", "DVTTextIndentUsingTabs", stock: false),
            t("page-guide", "Page guide", "A line marking a column in the editor.", "DVTTextShowPageGuide", stock: false),
            .slider("xcode.page-guide-column", "Page guide column", "Which character column the vertical page guide marks.",
                    in: .apps, "Xcode", d, "DVTTextPageGuideLocation",
                    NumberInput(60...160, step: 1, isInteger: true), stock: 80, effect: .appRelaunch),
            t("skip-macro-validation", "Skip macro validation", "Trust Swift macros without asking.", "IDESkipMacroFingerprintValidation", stock: false,
              caution: "Macros run code on your Mac during a build. Only skip this for packages you trust."),
            t("skip-plugin-validation", "Skip package plug-in validation", "Trust package plug-ins without asking.", "IDESkipPackagePluginFingerprintValidatation", stock: false,
              caution: "Plug-ins run code on your Mac during a build. Only skip this for packages you trust."),
            .toggle("simulator.bezels", "Simulator device bezels", "Draw the device around the simulated screen.",
                    in: .apps, "Xcode", app("com.apple.iphonesimulator"), "ShowChrome", stock: true, effect: .appRelaunch),
        ]
    }()

    // MARK: Continuity, privacy, screen saver

    static let continuity: [Tweak] = [
        .toggle("continuity.handoff", "Handoff",
                "Pick up on this Mac what you started on another device, and the reverse.",
                in: .sharing, "Continuity", .currentHost("com.apple.coreservices.useractivityd"), "ActivityAdvertisingAllowed",
                stock: true, effect: .logout),
        .toggle("continuity.handoff-receive", "Receive Handoff",
                "Show apps from your other devices in the Dock.",
                in: .sharing, "Continuity", .currentHost("com.apple.coreservices.useractivityd"), "ActivityReceivingAllowed",
                stock: true, effect: .logout),
        .toggle("continuity.clipboard", "Universal Clipboard",
                "Copy on one device and paste on another.",
                in: .sharing, "Continuity", .app("com.apple.coreservices.useractivityd"), "ClipboardSharingEnabled",
                stock: true, effect: .logout),
        .toggle("continuity.universal-control", "Universal Control",
                "Use this Mac's keyboard and pointer on a nearby Mac or iPad.",
                in: .sharing, "Continuity", .app("com.apple.universalcontrol"), "Disable", stock: true,
                on: .bool(false), off: .bool(true), effect: .logout),
        .toggle("continuity.edge-push", "Push through the edge to connect",
                "Move the pointer past the screen edge to reach the other device.",
                in: .sharing, "Continuity", .app("com.apple.universalcontrol"), "DisableMagicEdges", stock: true,
                on: .bool(false), off: .bool(true), effect: .logout),
        .choice("continuity.airdrop", "AirDrop visibility", "Who can see this Mac in AirDrop.",
                in: .sharing, "Continuity", .app("com.apple.sharingd"), "DiscoverableMode",
                [("off", "No One", .string("Off")), ("contacts", "Contacts Only", .string("Contacts Only")),
                 ("everyone", "Everyone", .string("Everyone"))],
                stock: "contacts", effect: .logout),
        .toggle("continuity.airdrop-ethernet", "AirDrop over Ethernet",
                "Find AirDrop devices over a wired network too.",
                in: .sharing, "Continuity", .app("com.apple.NetworkBrowser"), "BrowseAllInterfaces", stock: false, effect: .logout),
    ]

    static let privacy: [Tweak] = [
        .toggle("privacy.personalized-ads", "Personalized ads",
                "Let Apple use what it knows about you to pick ads in the App Store and News.",
                in: .security, "Advertising", .app("com.apple.AdLib"), "allowApplePersonalizedAdvertising", stock: true, effect: .logout),
        .toggle("privacy.ad-identifier", "Advertising identifier",
                "Let apps read an ID used to measure ads.",
                in: .security, "Advertising", .app("com.apple.AdLib"), "allowIdentifierForAdvertising", stock: true, effect: .logout),
        .choice("privacy.crash-dialog", "When an app crashes", "What macOS shows after an app quits unexpectedly.",
                in: .security, "Analytics", .app("com.apple.CrashReporter"), "DialogType",
                [("crashreport", "Show a Report", .string("crashreport")), ("basic", "Show a Short Notice", .string("basic")),
                 ("developer", "Show Technical Details", .string("developer")), ("none", "Show Nothing", .string("none"))],
                stock: "crashreport"),
        .toggle("privacy.crash-notification", "Crash reports as notifications",
                "Show a notification instead of a window.",
                in: .security, "Analytics", .app("com.apple.CrashReporter"), "UseUNC", stock: false),
    ]

    static let screenSaver: [Tweak] = [
        .choice("screensaver.start", "Start screen saver after", "How long the Mac sits idle before the screen saver starts.",
                in: .system, "Screen Saver", .currentHost("com.apple.screensaver"), "idleTime",
                [("never", "Never", .int(0)), ("1", "1 Minute", .int(60)), ("5", "5 Minutes", .int(300)),
                 ("10", "10 Minutes", .int(600)), ("20", "20 Minutes", .int(1200)), ("60", "1 Hour", .int(3600))],
                stock: "20", effect: .logout),
    ]
}
