import Foundation
import Testing
@testable import MacKitCore

/// Runs every read-only check against the real machine and prints what it
/// finds. Nothing is changed. Off unless `MACKIT_LIVE=1`, because the answer
/// depends on the Mac it runs on.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MACKIT_LIVE"] == "1"))
struct LiveProbeTests {
    @Test func everyProbeReadsThisMac() async throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let access = SystemAccess(
            preferences: SystemPreferenceStore(), commands: AllowlistedCommandRunner(),
            privileged: InMemorySystem(), fileFlags: SystemFileFlagStore(), homeDirectory: home
        )
        let engine = TweakEngine(system: access)
        let tweaks = Catalog.tweaks(home: home)
        let states = await engine.states(of: tweaks)
        for tweak in tweaks {
            let state = states[tweak.id] ?? .unknown
            let text: String = switch state {
            case .option(let id): id == tweak.stockOptionID ? "stock (\(id))" : "CHANGED (\(id))"
            case .custom(let raw): "CUSTOM \(raw)"
            case .unknown: "UNKNOWN"
            }
            print("LIVE \(tweak.id.padding(toLength: 34, withPad: " ", startingAt: 0)) \(text)")
        }
    }
}
