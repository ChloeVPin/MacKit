import Foundation
import Testing
@testable import MacKitCore

/// Flips real settings on this Mac for a moment and puts them back, to see
/// whether running apps notice. Only runs when asked:
/// `MACKIT_LIVE_APPLY=1 swift test --filter LiveApplyTests`.
/// Watch a running app (or a small observer) while it goes.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MACKIT_LIVE_APPLY"] != nil), .serialized)
struct LiveApplyTests {
    struct Step {
        var name: String
        var domain: String
        var key: String
        var value: Any
        var signal: LiveSignal
    }

    static let global = kCFPreferencesAnyApplication as String
    static let access = "com.apple.universalaccess"
    static var steps: [Step] { [
        Step(name: "appearance", domain: global, key: "AppleInterfaceStyle", value: "Dark", signal: .appearance),
        Step(name: "accent", domain: global, key: "AppleAccentColor", value: 5, signal: .appearance),
        Step(name: "glass", domain: global, key: "NSGlassTintAmount", value: 0.9, signal: .glass),
        Step(name: "wallpaperTint", domain: global, key: "AppleReduceDesktopTinting", value: true, signal: .wallpaperTint),
        Step(name: "scrollBars", domain: global, key: "AppleShowScrollBars", value: "WhenScrolling", signal: .scrollBars),
        Step(name: "sidebarSize", domain: global, key: "NSTableViewDefaultSizeMode", value: 3, signal: .sidebarSize),
        Step(name: "menuBar", domain: global, key: "_HIHideMenuBar", value: true, signal: .menuBar),
        Step(name: "keyboardNavigation", domain: global, key: "AppleKeyboardUIMode", value: 2, signal: .keyboardNavigation),
        Step(name: "pointerSize", domain: access, key: "mouseDriverCursorSize", value: 2.0, signal: .pointerSize),
        Step(name: "reduceMotion", domain: access, key: "reduceMotion", value: true, signal: .reduceMotion),
        Step(name: "reduceTransparency", domain: access, key: "reduceTransparency", value: true, signal: .reduceTransparency),
        Step(name: "increaseContrast", domain: access, key: "increaseContrast", value: true, signal: .increaseContrast),
        Step(name: "withoutColor", domain: access, key: "differentiateWithoutColor", value: true, signal: .differentiateWithoutColor),
        Step(name: "trackpadRotate", domain: "com.apple.AppleMultitouchTrackpad", key: "TrackpadRotate", value: 0, signal: .inputDevices),
    ] }

    func read(_ step: Step) -> Any? {
        CFPreferencesSynchronize(step.domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return CFPreferencesCopyValue(step.key as CFString, step.domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    func write(_ value: Any?, _ step: Step) -> Bool {
        CFPreferencesSetValue(step.key as CFString, value as CFPropertyList?, step.domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return CFPreferencesSynchronize(step.domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    func mark(_ text: String) {
        print("MARK \(text)")
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("Marker.Accessibility.\(text)"), object: nil, userInfo: nil, deliverImmediately: true)
    }

    @Test func flipEachSettingAndPutItBack() async throws {
        let only = ProcessInfo.processInfo.environment["MACKIT_LIVE_APPLY"]
        for step in Self.steps where only == "1" || only == step.name {
            let original = read(step)
            print("BACKUP \(step.name) \(step.key) = \(original.map { "\($0)" } ?? "<absent>")")
            mark("\(step.name).on")
            // Choosing Light or Dark also turns Auto off, as the real setting does.
            let auto = Step(name: "auto", domain: Self.global, key: "AppleInterfaceStyleSwitchesAutomatically", value: true, signal: .appearance)
            let originalAuto = read(auto)
            if step.name == "appearance" { _ = write(nil, auto) }
            let wrote = write(step.value, step)
            announceToSystem(step.signal)
            try await Task.sleep(for: .seconds(1.5))
            if step.name == "trackpadRotate" { print("DRIVER \(driverState())") }
            mark("\(step.name).off")
            if step.name == "appearance" { _ = write(originalAuto, auto) }
            let restored = write(original, step)
            announceToSystem(step.signal)
            try await Task.sleep(for: .seconds(1.5))
            if step.name == "trackpadRotate" { print("DRIVER \(driverState())") }
            let after = read(step)
            print("RESULT \(step.name) wrote=\(wrote) restored=\(restored) back=\(after.map { "\($0)" } ?? "<absent>")")
            #expect("\(String(describing: after))" == "\(String(describing: original))")
        }
    }

    func driverState() -> String {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/sbin/ioreg")
        process.arguments = ["-r", "-c", "AppleMultitouchDevice", "-l"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        let text = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let match = text.firstMatch(of: /"TrackpadRotate"=\d/)
        return match.map { String($0.0) } ?? "not found"
    }
}
