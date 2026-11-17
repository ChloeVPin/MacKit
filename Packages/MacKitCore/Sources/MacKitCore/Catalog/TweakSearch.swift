import Foundation

extension Catalog {
    /// Common words people search for that don't appear in a setting's own
    /// title or summary.
    private static let synonyms: [Tweak.ID: String] = [
        "appearance.mode": "dark mode light mode night theme",
        "appearance.glass-tint": "frosted blur transparency",
        "appearance.corners": "rounded radius square",
        "finder.hidden-files": "dotfiles dot files invisible",
        "finder.extensions": "file extensions suffixes",
        "finder.ds-store-network": "smb nas network share",
        "desktop.stacks": "group piles",
        "dock.autohide": "auto hide dock",
        "dock.reveal-speed": "autohide delay",
        "trackpad.secondary-click": "right click two finger click",
        "mouse.magic-secondary": "right click",
        "trackpad.natural-scrolling": "reverse scroll direction",
        "keyboard.press-and-hold": "character picker accents repeat",
        "power.lid-closed": "clamshell insomnia nosleep",
        "power.battery.network-wake": "wake on lan wol",
        "power.adapter.network-wake": "wake on lan wol",
        "sharing.ssh": "openssh terminal remote shell",
        "sharing.screen": "vnc remote desktop",
        "sharing.files": "smb samba network share",
        "security.touch-id-sudo": "pam fingerprint terminal password",
        "startup.chime": "boot sound mute",
        "backup.full-speed": "throttle io disk speed",
    ]

    /// Finds settings matching `query`, ordered from strongest match to
    /// weakest, breaking ties in catalog order.
    ///
    /// Multi-word queries match across fields (for example "dock size",
    /// "mouse speed", or "safari url"), and options and preference keys are
    /// searched alongside plain-English text.
    public static func search(_ query: String, in tweaks: [Tweak], locale: Locale = .current) -> [Tweak] {
        let foldedQuery = fold(query.trimmingCharacters(in: .whitespacesAndNewlines), locale: locale)
        let tokens = foldedQuery.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return [] }

        var scored: [(index: Int, score: Int, tweak: Tweak)] = []
        scored.reserveCapacity(32)

        for (index, tweak) in tweaks.enumerated() {
            if let score = score(of: tweak, foldedQuery: foldedQuery, tokens: tokens, locale: locale) {
                scored.append((index, score, tweak))
            }
        }

        scored.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.index < b.index
        }
        return scored.map(\.tweak)
    }

    private static func score(of tweak: Tweak, foldedQuery: String, tokens: [String], locale: Locale) -> Int? {
        let title = fold(tweak.title, locale: locale)
        let titleWords = words(in: title)
        let location = fold("\(tweak.category.title) \(tweak.category.rawValue) \(tweak.section)", locale: locale)
        let locationWords = words(in: location)
        let options = fold(tweak.options.map(\.label).joined(separator: " "), locale: locale)
        let optionWords = words(in: options)
        let summary = fold(tweak.caution.map { "\(tweak.summary) \($0)" } ?? tweak.summary, locale: locale)
        let summaryWords = words(in: summary)
        let technical = fold(technicalTerms(for: tweak), locale: locale)

        var total = 0
        var allInTitle = true
        var allInTitleOrLocation = true

        for token in tokens {
            if titleWords.contains(token) {
                total += 140
            } else if titleWords.contains(where: { $0.hasPrefix(token) }) {
                total += 115
            } else if title.contains(token) {
                total += 85
            } else if locationWords.contains(where: { $0.hasPrefix(token) }) || location.contains(token) {
                allInTitle = false
                total += 45
            } else if optionWords.contains(where: { $0.hasPrefix(token) }) || options.contains(token) {
                allInTitle = false
                allInTitleOrLocation = false
                total += 40
            } else if summaryWords.contains(where: { $0.hasPrefix(token) }) || summary.contains(token) {
                allInTitle = false
                allInTitleOrLocation = false
                total += 30
            } else if technical.contains(token) {
                allInTitle = false
                allInTitleOrLocation = false
                total += 25
            } else {
                return nil
            }
        }

        if title == foldedQuery {
            total += 1000
        } else if title.hasPrefix(foldedQuery) {
            total += 500
        } else if titleWords.contains(foldedQuery) {
            total += 350
        } else if title.contains(foldedQuery) {
            total += 250
        } else if summary.contains(foldedQuery) {
            total += 60
        }

        if tokens.count > 1 {
            if allInTitle {
                total += 90
            } else if allInTitleOrLocation {
                total += 50
            }
        }

        return total
    }

    private static func technicalTerms(for tweak: Tweak) -> String {
        var parts = [tweak.id]
        if let extra = synonyms[tweak.id] { parts.append(extra) }
        switch tweak.mechanism {
        case .preferences(let bindings):
            for binding in bindings {
                parts.append(binding.domain.commandLineName)
                parts.append(contentsOf: binding.path)
                parts.append(binding.key)
            }
        case .libraryVisibility:
            parts.append("chflags ~/Library hidden")
        case .privileged(let setting):
            parts.append(setting.storage)
            parts.append(setting.probe.command.executable)
        }
        return parts.joined(separator: " ")
    }

    private static func fold(_ text: String, locale: Locale) -> String {
        // Use locale-independent folding and unify Turkish dotted/dotless I so
        // English catalog titles like "Icon size" always match in every locale.
        _ = locale
        return text
            .replacing("ı", with: "i")
            .replacing("İ", with: "i")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func words(in foldedText: String) -> [String] {
        foldedText.split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }
}
