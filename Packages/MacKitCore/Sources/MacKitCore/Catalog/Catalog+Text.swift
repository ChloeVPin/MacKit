import Foundation

extension Catalog {
    /// Settings that hold a line of text the user types.
    static let textSettings: [Tweak] = [
        .text(
            "screenshot.name", "File name starts with",
            "The word at the start of each screenshot's name.",
            in: .screenshots, "Saving", .app("com.apple.screencapture"), "name",
            TextInput(placeholder: "Screenshot", maxLength: 60, forbidden: "/:", emptyLabel: "Screenshot"),
            effect: .restarts(.systemUIServer)
        ),
        .text(
            "login.message", "Lock screen message",
            "A line of text under the login window, such as who to call if this Mac is found.",
            in: .system, "Login Window", .system("/Library/Preferences/com.apple.loginwindow"), "LoginwindowText",
            TextInput(placeholder: "If found, call…", maxLength: 200),
            effect: .logout
        ),
        .text(
            "safari.home-page", "Homepage",
            "The page the Home button and Homepage windows open.",
            in: .apps, "Safari", .app("com.apple.Safari"), "HomePage",
            TextInput(placeholder: "https://www.apple.com/startpage", maxLength: 500, forbidden: " ", emptyLabel: "Apple Start Page"),
            effect: .appRelaunch
        ),
        Tweak(
            id: "sharing.computer-name", title: "Computer name",
            summary: "The name other devices see for this Mac, in AirDrop and on the network.",
            category: .sharing, section: "Sharing",
            options: [],
            stock: "",
            mechanism: .privileged(PrivilegedSetting(
                storage: "System configuration (ComputerName)",
                probe: Probe(
                    Command("/usr/sbin/scutil", "--get", "ComputerName"), [],
                    capture: .init(#"^\s*(.+?)\s*$"#, example: "{value}")
                ),
                commands: [:],
                valueCommands: [Command("/usr/sbin/scutil", "--set", "ComputerName", PrivilegedSetting.valuePlaceholder)]
            )),
            input: .text(TextInput(placeholder: "My Mac", maxLength: 63, emptyLabel: "")),
            hasDefault: false
        ),
    ]
}
