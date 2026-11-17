import Foundation
import Testing
@testable import MacKitCore

/// Writes every setting, its options, and the Terminal command for each
/// option to the file named by `MACKIT_DUMP`. Used to build capture briefs.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MACKIT_DUMP"] != nil))
struct CatalogDumpTests {
    @Test func writeCatalog() throws {
        let path = try #require(ProcessInfo.processInfo.environment["MACKIT_DUMP"])
        var lines: [String] = []
        for tweak in Catalog.tweaks(home: URL(filePath: "/Users/USER")) {
            let after: String = switch tweak.effect {
            case .immediate: "nothing"
            case .restarts(let target): "killall \(target.processName)"
            case .appRelaunch: "quit and reopen the app"
            case .logout: "log out and back in"
            case .nextStartup, .restart: "restart the Mac"
            }
            lines.append("## \(tweak.id)")
            lines.append("\(tweak.category.title) > \(tweak.section) > \(tweak.title)\(tweak.requiresAdministrator ? " [admin]" : "")\(tweak.requiresFullDiskAccess ? " [FDA]" : "")")
            lines.append(tweak.summary)
            lines.append("after: \(after)")
            for option in tweak.options {
                let stock = tweak.hasDefault && option.id == tweak.stockOptionID ? " (stock)" : ""
                lines.append("- \(option.id)\(stock) \"\(option.label)\": \(commands(tweak, option.id).joined(separator: " ; "))")
            }
            if let input = tweak.input { lines.append("input: \(input)") }
            lines.append("")
        }
        try lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }

    private func commands(_ tweak: Tweak, _ option: TweakOption.ID) -> [String] {
        switch tweak.mechanism {
        case .preferences(let bindings):
            bindings.map { Operation.writePreference(domain: $0.domain, path: $0.path, key: $0.key, value: $0.values[option]).commandText }
        case .libraryVisibility:
            [Operation.setLibraryHidden(option == "off").commandText]
        case .privileged(let setting):
            (setting.commands[option] ?? []).map { "sudo " + $0.shellText }
        }
    }
}
