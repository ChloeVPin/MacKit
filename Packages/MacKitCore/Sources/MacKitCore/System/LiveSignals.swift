import Foundation

/// Tells macOS that a saved setting changed, the way System Settings does
/// after it saves one.
///
/// Saving a preference only reaches apps the next time they start. Each of
/// these has its own way of reaching what's already running: a notification
/// apps listen for, a call to the window server, or a call into AppKit.
/// None of the calls are public, so each is looked up by name and skipped if
/// a future macOS drops it. The saved value still applies at the next login.
public func announceToSystem(_ signal: LiveSignal) {
    switch signal {
    case .appearance:
        let isAutomatic = global("AppleInterfaceStyleSwitchesAutomatically") as? Bool ?? false
        let isDark = global("AppleInterfaceStyle") as? String == "Dark"
        typealias Setter = @convention(c) (Bool) -> Void
        if let set = skyLight("SLSSetAppearanceThemeSwitchesAutomatically", as: Setter.self) { set(isAutomatic) }
        // With Auto on, macOS picks light or dark itself from the time of day.
        if !isAutomatic, let set = skyLight("SLSSetAppearanceThemeLegacy", as: Setter.self) { set(isDark) }
        post("AppleInterfaceThemeChangedNotification", "AppleColorPreferencesChangedNotification", "AppleAquaColorVariantChanged")

    case .glass:
        let amount = (global("NSGlassTintAmount") as? NSNumber)?.floatValue ?? 0.5
        // AppKit touches windows here, so it has to be the main thread.
        DispatchQueue.main.async { setGlassTint(amount) }

    case .wallpaperTint:
        post("AppleReduceDesktopTintingChanged")

    case .scrollBars:
        post("AppleShowScrollBarsSettingChanged")

    case .sidebarSize:
        post("AppleSideBarDefaultIconSizeChanged")

    case .menuBar:
        let hides = global("_HIHideMenuBar") as? Bool ?? false
        typealias Setter = @convention(c) (Int32, Bool) -> Int32
        if let connection, let set = skyLight("SLSSetMenuBarAutohideEnabled", as: Setter.self) { _ = set(connection, hides) }
        post("AppleInterfaceMenuBarHidingChangedNotification", "AppleInterfaceFullScreenMenuBarVisibilityChangedNotification")

    case .pointerSize:
        let size = (universalAccess("mouseDriverCursorSize") as? NSNumber)?.floatValue ?? 1
        typealias Setter = @convention(c) (Int32, Float) -> Int32
        if let connection, let set = skyLight("SLSSetCursorScale", as: Setter.self) { _ = set(connection, size) }

    case .keyboardNavigation:
        post("com.apple.KeyboardUIModeDidChange")

    case .inputDevices:
        // The helper System Settings uses to push saved keyboard, mouse, and
        // trackpad settings to the drivers.
        let helper = URL(filePath: "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings")
        let process = Process()
        process.executableURL = helper
        process.arguments = ["-u"]
        try? process.run()
        post(
            "com.apple.AppleMultitouchTrackpadDomainDidChangeNotification", "com.apple.AppleMultitouchMouseDomainDidChangeNotification",
            "SwipeScrollDirectionDidChangeNotification", "com.apple.keyboard.fnstatedidchange"
        )

    // Apps re-read these from the saved setting when they hear the change.
    case .reduceMotion:
        post("AXInterfaceReduceMotionStatusDidChange")
    case .reduceTransparency:
        post("AXInterfaceReduceTransparencyStatusDidChange")
    case .increaseContrast:
        post("AXInterfaceIncreaseContrastStatusDidChange")
    case .differentiateWithoutColor:
        post("AXInterfaceDifferentiateWithoutColorStatusDidChange")
    case .buttonShapes:
        post("AXInterfaceShowToolbarButtonShapesStatusDidChangeNotification")
    }
}

// MARK: - Reading what was saved

// `UserDefaults(suiteName:)` refuses the global domain and returns nil, so
// these go through CFPreferences.
private func global(_ key: String) -> Any? {
    CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    return CFPreferencesCopyValue(key as CFString, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
}

private func universalAccess(_ key: String) -> Any? {
    let domain = "com.apple.universalaccess" as CFString
    CFPreferencesAppSynchronize(domain)
    return CFPreferencesCopyAppValue(key as CFString, domain)
}

// MARK: - Reaching the system

private func post(_ names: String...) {
    let center = DistributedNotificationCenter.default()
    for name in names {
        center.postNotificationName(Notification.Name(name), object: nil, userInfo: nil, deliverImmediately: true)
    }
}

private func symbol<Function>(_ name: String, in library: String, as type: Function.Type) -> Function? {
    guard let handle = dlopen(library, RTLD_LAZY), let symbol = dlsym(handle, name) else { return nil }
    return unsafeBitCast(symbol, to: type)
}

private func skyLight<Function>(_ name: String, as type: Function.Type) -> Function? {
    symbol(name, in: "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", as: type)
}

/// This process's connection to the window server.
private var connection: Int32? {
    skyLight("SLSMainConnectionID", as: (@convention(c) () -> Int32).self)?()
}

/// Sets how frosted Liquid Glass is, everywhere, at once.
///
/// This is AppKit's `NSGlassEffectView.Legibility.setSystemLegibility`, the
/// call behind the slider in System Settings. It's a Swift function AppKit
/// doesn't publish, so before passing the hand-laid-out `Legibility?` buffer
/// MacKit checks AppKit's exported runtime type metadata and enum case tag to
/// confirm `Legibility` still has the expected 5-byte / 8-stride layout with
/// `tintAmount(Float)` at case 0.
private func setGlassTint(_ amount: Float) {
    typealias Setter = @convention(c) (UnsafeRawPointer, @convention(c) () -> Void, UnsafeRawPointer?) -> Void
    let library = "/System/Library/Frameworks/AppKit.framework/AppKit"
    let name = "$sSo17NSGlassEffectViewC6AppKitE10LegibilityO09setSystemF0_17completionHandleryAESg_yyctFZ"
    guard let handle = dlopen(library, RTLD_LAZY),
          let layout = glassLegibilityLayout(in: handle),
          let legibility = glassLegibilityBuffer(amount: amount, layout: layout),
          let set = symbol(name, in: library, as: Setter.self) else { return }
    legibility.withUnsafeBytes { set($0.baseAddress!, {}, nil) }
}

struct GlassLegibilityLayout: Equatable, Sendable {
    var size: Int
    var stride: Int
    var tintAmountTag: UInt32
}

func glassLegibilityLayout(in handle: UnsafeMutableRawPointer) -> GlassLegibilityLayout? {
    typealias MetadataAccessor = @convention(c) (Int) -> UnsafeRawPointer
    guard let accessorSym = dlsym(handle, "$sSo17NSGlassEffectViewC6AppKitE10LegibilityOMa"),
          let tagSym = dlsym(handle, "$sSo17NSGlassEffectViewC6AppKitE10LegibilityO10tintAmountyAESfcAEmFWC") else {
        return nil
    }
    let metadata = unsafeBitCast(accessorSym, to: MetadataAccessor.self)(0)
    let valueWitnessTable = metadata.advanced(by: -MemoryLayout<UnsafeRawPointer>.size).load(as: UnsafeRawPointer.self)
    let size = valueWitnessTable.advanced(by: 8 * MemoryLayout<UnsafeRawPointer>.size).load(as: Int.self)
    let stride = valueWitnessTable.advanced(by: 9 * MemoryLayout<UnsafeRawPointer>.size).load(as: Int.self)
    let tag = tagSym.load(as: UInt32.self)
    return GlassLegibilityLayout(size: size, stride: stride, tintAmountTag: tag)
}

func glassLegibilityBuffer(amount: Float, layout: GlassLegibilityLayout) -> [UInt8]? {
    // `Legibility` is `tintAmount(Float)` (4-byte Float + 1-byte enum tag = 5
    // bytes, stride 8), and `Optional<Legibility>` adds 1 byte (`0` = `.some`)
    // at offset 5 inside the same 8-byte slot. Bail out if AppKit changes it.
    guard layout == GlassLegibilityLayout(size: 5, stride: 8, tintAmountTag: 0) else { return nil }
    var legibility = [UInt8](repeating: 0, count: 8)
    withUnsafeBytes(of: amount) { legibility.replaceSubrange(0..<4, with: $0) }
    return legibility
}
