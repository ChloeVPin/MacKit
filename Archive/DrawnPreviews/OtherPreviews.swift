import SwiftUI

// MARK: - Screenshots

struct ScreenshotPreview: View {
    let id: String
    let option: String?

    private var isOn: Bool { option == "on" }

    var body: some View {
        Group {
            switch id {
            case "screenshot.format": format
            case "screenshot.location": location
            case "screenshot.shadow": shadow
            default: thumbnail
            }
        }
        .animation(Motion.surface, value: option)
    }

    private var capture: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(LinearGradient(colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.85)).frame(width: 30, height: 18).padding(6)
            }
    }

    private var format: some View {
        let (ext, size): (String, String) = switch option {
        case "jpg": ("jpg", "0.9 MB")
        case "heic": ("heic", "0.6 MB")
        case "pdf": ("pdf", "3.1 MB")
        case "tiff": ("tiff", "14.8 MB")
        default: ("png", "2.4 MB")
        }
        return MiniPanel(width: 280) {
            HStack(spacing: 12) {
                capture.frame(width: 70, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    (Text("Screenshot.") + Text(ext).foregroundStyle(Color.accentColor).fontWeight(.semibold))
                        .mini(size: 11)
                        .contentTransition(.opacity)
                    Text("\(ext.uppercased()) image · about \(size)")
                        .mini()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var location: some View {
        HStack(spacing: 26) {
            ForEach(["desktop", "downloads", "pictures"], id: \.self) { folder in
                VStack(spacing: 6) {
                    ZStack {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 58))
                            .foregroundStyle(.blue.gradient)
                        if option == folder {
                            capture
                                .frame(width: 34, height: 23)
                                .shadow(radius: 3, y: 1)
                                .offset(y: 4)
                                .transition(.scale(scale: 0.4).combined(with: .opacity))
                        }
                    }
                    Text(folder.capitalized)
                        .mini(size: 10.5, weight: option == folder ? .semibold : .regular)
                        .foregroundStyle(.white)
                }
                .opacity(option == folder ? 1 : 0.55)
            }
        }
    }

    private var shadow: some View {
        ZStack {
            // A plain backdrop, since the shadow is the subject.
            Rectangle().fill(Color(nsColor: .windowBackgroundColor))
            MiniWindow(title: "Notes", width: 220, height: 130) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule().fill(.primary.opacity(0.12)).frame(width: index == 3 ? 90 : 180, height: 5)
                    }
                }
                .padding(12)
            }
            .shadow(color: .black.opacity(isOn ? 0.3 : 0), radius: 18, y: 10)
            .compositingGroup()
            .overlay {
                if !isOn {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.primary.opacity(0.25), lineWidth: 0.5)
                }
            }
            StageCaption(text: isOn ? "Saved with its shadow" : "Saved with a clean edge")
        }
    }

    private var thumbnail: some View {
        ZStack {
            MiniMenuBar()
            PlaceholderWindow().offset(y: -22)
            MiniDock()
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 10)
            if isOn {
                capture
                    .frame(width: 84, height: 56)
                    .overlay { RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(.white, lineWidth: 2) }
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(12)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                StageCaption(text: "Saved immediately, with no preview")
                    .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - Keyboard

struct KeyboardPreview: View {
    let id: String
    let option: String?

    private var isOn: Bool { option == "on" }

    var body: some View {
        Group {
            switch id {
            case "keyboard.press-and-hold": pressAndHold
            case "keyboard.repeat-rate": repeatRate
            case "keyboard.repeat-delay": repeatDelay
            case "text.autocorrect": correction(typed: "teh quick fox", corrected: "the quick fox")
            case "text.capitalize": correction(typed: "hello. how are you", corrected: "Hello. How are you")
            case "text.period": correction(typed: "Done␣␣Next", corrected: "Done. Next")
            case "text.smart-quotes": correction(typed: "\"hello\" it's", corrected: "“hello” it’s")
            default: correction(typed: "wait--what", corrected: "wait—what")
            }
        }
        .animation(Motion.surface, value: option)
    }

    /// A text field with a blinking caret after `text`.
    private func field(_ text: String, phase: Double = 0, width: CGFloat = 300) -> some View {
        HStack(spacing: 1) {
            Text(text)
                .font(.system(size: 20, weight: .regular, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.head)
            Rectangle().fill(Color.accentColor).frame(width: 2, height: 24)
                .opacity(phase.truncatingRemainder(dividingBy: 0.5) < 0.3 ? 1 : 0.25)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(width: width, height: 52)
        .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }

    private func keycap(_ label: String, pressed: Bool) -> some View {
        Text(label)
            .font(.system(size: 15, weight: .medium))
            .frame(width: 40, height: 40)
            .background(Color(nsColor: .windowBackgroundColor), in: .rect(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: pressed ? 1 : 4, y: pressed ? 0.5 : 3)
            .offset(y: pressed ? 2 : 0)
    }

    private var pressAndHold: some View {
        Loop(period: 3, restingPhase: 0.6) { phase in
            let held = phase > 0.12 && phase < 0.85
            let repeats = held ? Int((phase - 0.2) * 34) : 0
            VStack(spacing: 22) {
                ZStack(alignment: .top) {
                    field(isOn ? (held ? "e" : "") : String(repeating: "e", count: max(held ? 1 : 0, repeats)), phase: phase)
                    if isOn, phase > 0.3, phase < 0.85 {
                        HStack(spacing: 0) {
                            ForEach(Array(["è", "é", "ê", "ë", "ē"].enumerated()), id: \.offset) { index, letter in
                                VStack(spacing: 1) {
                                    Text(letter).font(.system(size: 15))
                                    Text("\(index + 1)").font(.system(size: 8)).foregroundStyle(.secondary)
                                }
                                .frame(width: 28, height: 38)
                            }
                        }
                        .padding(.horizontal, 4)
                        .background(Color(nsColor: .windowBackgroundColor), in: .rect(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
                        .offset(x: -100, y: -30)
                    }
                }
                keycap("E", pressed: held)
            }
        }
    }

    private var repeatRate: some View {
        // Seconds between repeats, from the values macOS stores.
        let interval: Double = switch option {
        case "fast": 0.030
        case "fastest": 0.015
        default: 0.090
        }
        return typing(delay: 0.375, interval: interval)
    }

    private var repeatDelay: some View {
        let delay: Double = switch option {
        case "short": 0.225
        case "shortest": 0.150
        default: 0.375
        }
        return typing(delay: delay, interval: 0.09)
    }

    /// Holds a key for two seconds, showing the delay and then the repeats.
    private func typing(delay: Double, interval: Double) -> some View {
        let period = 2.8
        return Loop(period: period, restingPhase: 0.5) { phase in
            let time = phase * period
            let held = time > 0.3 && time < 2.3
            let since = time - 0.3
            let count = !held ? 0 : since < delay ? 1 : 1 + Int((since - delay) / interval)
            VStack(spacing: 22) {
                field(String(repeating: "a", count: count), phase: phase)
                keycap("A", pressed: held)
            }
        }
    }

    private func correction(typed: String, corrected: String) -> some View {
        VStack(spacing: 12) {
            labeled("You type", typed, emphasized: false)
            Image(systemName: "arrow.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
            labeled("You get", isOn ? corrected : typed.replacingOccurrences(of: "␣", with: " "), emphasized: isOn)
        }
    }

    private func labeled(_ label: String, _ text: String, emphasized: Bool) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .mini(size: 10, weight: .medium)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            // Not monospaced: curly quotes and dashes only look different
            // from straight ones in a proportional face.
            Text(text)
                .font(.system(size: 18))
                .lineLimit(1)
                .contentTransition(.opacity)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(width: 320, height: 46)
        .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 10, style: .continuous))
        .overlay {
            if emphasized {
                RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.accentColor.opacity(0.8), lineWidth: 1.5)
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
    }
}

// MARK: - Windows

struct WindowsPreview: View {
    let id: String
    let option: String?

    private var isOn: Bool { option == "on" }

    var body: some View {
        Group {
            switch id {
            case "windows.save-expanded": saveDialog(showsLocationOnly: false)
            case "windows.print-expanded": printDialog
            case "windows.save-to-icloud": saveDialog(showsLocationOnly: true)
            case "windows.confirm-close": confirmClose
            case "windows.scroll-bars": scrollBars
            default: restore
            }
        }
        .animation(Motion.surface, value: option)
    }

    private func line(_ width: CGFloat) -> some View {
        Capsule().fill(.primary.opacity(0.12)).frame(width: width, height: 5)
    }

    private func fieldRow(_ label: String, @ViewBuilder value: () -> some View) -> some View {
        HStack(spacing: 6) {
            Text(label).mini().foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
            HStack(spacing: 4, content: value)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 18)
                .background(.primary.opacity(0.07), in: .rect(cornerRadius: 4))
        }
    }

    private func saveDialog(showsLocationOnly: Bool) -> some View {
        let expanded = !showsLocationOnly && isOn
        return MiniPanel(width: expanded ? 330 : 250) {
            VStack(spacing: 8) {
                fieldRow("Save As:") { Text("Untitled").mini() }
                if expanded {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(["Desktop", "Documents", "Downloads"], id: \.self) { name in
                                Label(name, systemImage: "folder").mini(size: 9)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(7)
                        .frame(width: 96, alignment: .leading)
                        Rectangle().fill(.primary.opacity(0.1)).frame(width: 0.5)
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(["Archive", "Projects", "Budget.numbers", "Notes.txt"], id: \.self) { name in
                                Label(name, systemImage: name.contains(".") ? "doc" : "folder").mini(size: 9)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 92)
                    .background(.primary.opacity(0.04), in: .rect(cornerRadius: 5))
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                } else {
                    fieldRow("Where:") {
                        let cloud = showsLocationOnly && isOn
                        Image(systemName: cloud ? "icloud" : "folder").font(.system(size: 8)).foregroundStyle(showsLocationOnly ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                        Text(cloud ? "iCloud Drive" : showsLocationOnly ? "Documents — On My Mac" : "Documents")
                            .mini(weight: showsLocationOnly ? .semibold : .regular)
                            .contentTransition(.opacity)
                    }
                }
                HStack(spacing: 6) {
                    Spacer()
                    MiniButton(title: "Cancel").frame(width: 56)
                    MiniButton(title: "Save", prominent: true).frame(width: 56)
                }
            }
        }
    }

    private var printDialog: some View {
        MiniPanel(width: isOn ? 330 : 250) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .overlay {
                        VStack(alignment: .leading, spacing: 4) { line(40); line(52); line(30); line(48) }
                    }
                    .frame(width: 74, height: isOn ? 122 : 78)
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                VStack(spacing: 7) {
                    fieldRow("Printer:") { Text("Office").mini() }
                    fieldRow("Copies:") { Text("1").mini() }
                    if isOn {
                        Group {
                            fieldRow("Pages:") { Text("All").mini() }
                            fieldRow("Paper:") { Text("US Letter").mini() }
                            fieldRow("Layout:") { Text("Two-Sided").mini() }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    HStack(spacing: 6) {
                        Spacer()
                        MiniButton(title: "Print", prominent: true).frame(width: 56)
                    }
                }
            }
        }
    }

    private var confirmClose: some View {
        ZStack {
            MiniWindow(title: isOn ? "Letter — Edited" : "Letter", width: 300, height: 170) {
                VStack(alignment: .leading, spacing: 7) { line(240); line(250); line(180); line(220); line(120) }
                    .padding(14)
            }
            if isOn {
                MiniPanel(width: 200) {
                    VStack(spacing: 8) {
                        Text("Keep changes to “Letter”?").mini(size: 10.5, weight: .semibold)
                        HStack(spacing: 6) {
                            MiniButton(title: "Revert")
                            MiniButton(title: "Save", prominent: true)
                        }
                    }
                }
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            } else {
                StageCaption(text: "Closes and saves without asking")
            }
        }
    }

    private var scrollBars: some View {
        Loop(period: 3, restingPhase: 0.5) { phase in
            // The page scrolls for the middle third of each cycle.
            let scrolling = phase > 0.3 && phase < 0.7
            let offset = ramp(phase, 0.3...0.7) - ramp(phase, 0.9...1)
            let visible: Double = switch option {
            case "always": 1
            case "scrolling": scrolling ? 1 : 0
            default: scrolling ? 1 : 0.35
            }
            MiniWindow(title: "Notes", width: 300, height: 180) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(0..<14, id: \.self) { index in line([220, 240, 170, 230, 200][index % 5]) }
                    }
                    .padding(14)
                    .offset(y: -60 * offset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipped()

                    Capsule().fill(.primary.opacity(0.4))
                        .frame(width: 5, height: 60)
                        .offset(y: 84 * offset)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.vertical, 4)
                        .padding(.trailing, 3)
                        .opacity(visible)
                        .animation(Motion.fade, value: visible)
                }
            }
        }
    }

    private var restore: some View {
        ZStack {
            if isOn {
                MiniWindow(title: "Budget", width: 210, height: 130) { VStack(alignment: .leading, spacing: 6) { line(160); line(120); line(150) }.padding(12) }
                    .offset(x: -50, y: -18)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                MiniWindow(title: "Letter", width: 210, height: 130) { VStack(alignment: .leading, spacing: 6) { line(170); line(140); line(90) }.padding(12) }
                    .offset(x: 50, y: 14)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            } else {
                MiniWindow(title: "Untitled", width: 210, height: 130) { EmptyView() }
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
            StageCaption(text: isOn ? "Opens with what you had before" : "Opens fresh each time")
        }
    }
}

// MARK: - System

struct SystemPreview: View {
    let id: String
    let option: String?

    private var isOn: Bool { option == "on" }

    var body: some View {
        Group {
            switch id {
            case "security.firewall": firewall
            case "security.stealth": stealth
            default: chime
            }
        }
        .animation(Motion.surface, value: option)
    }

    private var mac: some View {
        Image(nsImage: NSImage(named: NSImage.computerName) ?? NSImage())
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: 96, height: 96)
    }

    private func badge(_ symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 26))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, color)
            .shadow(radius: 3, y: 1)
    }

    private var firewall: some View {
        Loop(period: 2.2, restingPhase: 0.55) { phase in
            // A connection travels from the network toward the Mac.
            let travel = ramp(phase, 0.1...0.7)
            let limit = isOn ? 0.52 : 1.0
            HStack(spacing: 0) {
                Image(systemName: "globe")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.white)
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.3)).frame(width: 150, height: 2)
                    Circle().fill(.white)
                        .frame(width: 9, height: 9)
                        .offset(x: 141 * min(travel, limit))
                        .opacity(isOn && travel > limit ? 1 - ramp(phase, 0.5...0.75) : 1)
                    if isOn {
                        badge("shield.fill", color: .green)
                            .offset(x: 80)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 150)
                .padding(.horizontal, 12)
                mac
            }
        }
    }

    private var stealth: some View {
        Loop(period: 2.6, restingPhase: 0.7) { phase in
            let out = ramp(phase, 0.05...0.4)
            let reply = isOn ? 0 : ramp(phase, 0.45...0.8)
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Image(systemName: "desktopcomputer").font(.system(size: 38, weight: .light)).foregroundStyle(.white)
                    Text("Another device").mini(size: 9).foregroundStyle(.white.opacity(0.8))
                }
                VStack(spacing: 10) {
                    bubble("ping", progress: out, reversed: false)
                    bubble(isOn ? "no answer" : "pong", progress: isOn ? ramp(phase, 0.5...0.6) : reply, reversed: true, quiet: isOn)
                }
                .frame(width: 170)
                mac.opacity(isOn ? 0.45 : 1)
            }
        }
    }

    private func bubble(_ text: String, progress: Double, reversed: Bool, quiet: Bool = false) -> some View {
        Text(text)
            .mini(size: 10, weight: .medium)
            .foregroundStyle(quiet ? .white.opacity(0.7) : .black.opacity(0.8))
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(quiet ? AnyShapeStyle(.white.opacity(0.15)) : AnyShapeStyle(.white), in: .capsule)
            .offset(x: quiet ? 0 : (reversed ? 50 - 100 * progress : -50 + 100 * progress))
            .opacity(progress > 0 ? 1 : 0)
    }

    private var chime: some View {
        Loop(period: 2.4, restingPhase: 0.3) { phase in
            HStack(spacing: 26) {
                mac
                ZStack {
                    Image(systemName: isOn ? "speaker.wave.3.fill" : "speaker.slash.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                    if isOn {
                        ForEach(0..<2, id: \.self) { ring in
                            let progress = (phase + Double(ring) * 0.5).truncatingRemainder(dividingBy: 1)
                            Circle().strokeBorder(.white.opacity(0.5 * (1 - progress)), lineWidth: 1.5)
                                .frame(width: 60 + 70 * progress, height: 60 + 70 * progress)
                        }
                    }
                }
                .frame(width: 130, height: 130)
            }
        }
    }
}
