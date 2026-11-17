import Foundation

extension StoreCategory {
    /// Homebrew doesn't sort apps into categories, so the well-known ones
    /// are sorted here by hand. Every name was checked against the list.
    /// Apps not named here still appear under All and in search.
    static let members: [StoreCategory: [String]] = [
        .browsers: [
            "google-chrome", "firefox", "brave-browser", "microsoft-edge", "vivaldi", "opera",
            "zen", "orion", "tor-browser", "librewolf", "duckduckgo", "waterfox",
            "helium-browser", "firefox@developer-edition", "google-chrome@canary",
        ],
        .productivity: [
            "notion", "obsidian", "raycast", "alfred", "craft", "logseq",
            "anytype", "notion-calendar", "fantastical", "libreoffice", "onlyoffice", "evernote",
            "ticktick", "joplin", "zotero", "calibre", "anki", "superlist",
            "heptabase", "capacities", "reflect", "standard-notes", "appflowy", "typora",
            "skim", "pdf-expert", "todoist-app",
        ],
        .developer: [
            "visual-studio-code", "cursor", "zed", "ghostty", "iterm2", "warp",
            "docker-desktop", "orbstack", "postman", "insomnia", "tableplus", "dbeaver-community",
            "github", "sourcetree", "fork", "tower", "sublime-text", "jetbrains-toolbox",
            "android-studio", "webstorm", "utm", "proxyman", "bruno", "rapidapi",
            "kitty", "wezterm", "nova", "hex-fiend", "devtoys", "lens",
            "podman-desktop", "sequel-ace", "beekeeper-studio", "gitkraken", "xcodes-app",
        ],
        .communication: [
            "slack", "discord", "telegram", "whatsapp", "signal", "element",
            "thunderbird", "mimestream", "beeper", "wechat", "viber", "mattermost",
            "rocket-chat", "zulip", "loom",
        ],
        .media: [
            "spotify", "vlc", "iina", "obs", "handbrake-app", "audacity",
            "plex", "jellyfin-media-player", "tidal", "deezer", "foobar2000", "kodi",
            "stremio", "downie", "permute", "shotcut", "kdenlive", "losslesscut",
            "musicbrainz-picard", "subler", "transmission",
        ],
        .design: [
            "figma", "sketch", "blender", "gimp", "inkscape", "krita",
            "rawtherapee", "imageoptim", "framer", "zeplin", "drawio", "excalidrawz",
            "pika", "cleanshot", "shottr", "affinity",
        ],
        .utilities: [
            "rectangle", "stats", "maccy", "the-unarchiver", "keka", "appcleaner",
            "betterdisplay", "hiddenbar", "bartender", "alt-tab", "hammerspoon", "monitorcontrol",
            "caffeine", "itsycal", "coconutbattery", "onyx", "balenaetcher", "raspberry-pi-imager",
            "cyberduck", "transmit", "forklift", "commander-one", "mounty", "latest",
            "pearcleaner", "linearmouse", "mos", "scroll-reverser", "bettertouchtool", "keyboardcleantool",
            "aldente", "daisydisk", "grandperspective", "omnidisksweeper", "jordanbaird-ice", "loop",
            "swish", "shortcat",
        ],
        .security: [
            "1password", "bitwarden", "keepassxc", "protonvpn", "little-snitch", "lulu",
            "oversight", "knockknock", "proton-pass", "proton-mail", "proton-drive", "cryptomator",
        ],
        .ai: [
            "chatgpt", "claude", "ollama-app", "lm-studio", "jan", "perplexity",
            "boltai", "superwhisper", "macwhisper", "diffusionbee", "draw-things", "cherry-studio",
            "anythingllm",
        ],
        .games: [
            "steam", "epic-games", "minecraft", "prismlauncher", "crossover", "heroic",
            "moonlight", "retroarch", "dolphin", "godot", "unity-hub", "itch",
        ],
    ]

    private static let lookup: [String: StoreCategory] = Dictionary(
        members.flatMap { category, apps in apps.map { ($0, category) } },
        uniquingKeysWith: { first, _ in first }
    )

    static func of(_ app: String) -> StoreCategory? { lookup[app] }
}
