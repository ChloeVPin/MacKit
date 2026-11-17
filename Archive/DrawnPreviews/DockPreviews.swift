import SwiftUI

/// Previews for Dock settings: a desktop with a miniature Dock.
struct DockPreview: View {
    let id: String
    let option: String?

    private var isOn: Bool { option == "on" }

    var body: some View {
        Group {
            switch id {
            case "dock.autohide": autohide
            case "dock.reveal-speed": revealSpeed
            case "dock.position": position
            case "dock.recents": recents
            case "dock.minimize-effect": minimizeEffect
            case "dock.minimize-to-app": minimizeToApp
            case "dock.launch-animation": launch
            default: spaces
            }
        }
        .animation(Motion.surface, value: option)
    }

    private func desktop(dockOffset: CGFloat = 0, @ViewBuilder content: () -> some View = { EmptyView() }) -> some View {
        ZStack {
            MiniMenuBar()
            content()
            MiniDock()
                .offset(y: dockOffset)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 10)
        }
    }

    // MARK: Hide automatically

    private var autohide: some View {
        ZStack {
            desktop(dockOffset: isOn ? 64 : 0) {
                PlaceholderWindow().offset(y: -22)
            }
            StageCaption(text: isOn ? "Hidden until you move to the edge" : "Always visible")
                .padding(.bottom, isOn ? 0 : 50)
        }
    }

    // MARK: Reveal speed

    private var revealSpeed: some View {
        // Time the pointer waits at the edge, then time the Dock takes to slide in.
        let (delay, slide): (Double, Double) = switch option {
        case "fast": (0, 0.2)
        case "instant": (0, 0)
        default: (0.5, 0.5)
        }
        let period = 2.6
        return Loop(period: period, restingPhase: 0.7) { phase in
            let time = phase * period
            // The pointer reaches the edge at 0.5s. The Dock leaves at 2.1s.
            let shown = slide == 0 ? (time >= 0.5 + delay ? 1 : 0) : ramp(time, (0.5 + delay)...(0.5 + delay + slide))
            let hidden = ramp(time, 2.1...2.4)
            ZStack {
                desktop(dockOffset: 64 * (1 - shown + hidden)) { PlaceholderWindow().offset(y: -22) }
                Image(systemName: "cursorarrow")
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .shadow(radius: 1)
                    .offset(y: 40 + 78 * ramp(time, 0...0.5) - 60 * hidden)
            }
        }
    }

    // MARK: Position

    private var position: some View {
        let alignment: Alignment = switch option {
        case "left": .leading
        case "right": .trailing
        default: .bottom
        }
        return ZStack {
            MiniMenuBar()
            PlaceholderWindow().offset(y: option == "bottom" || option == nil ? -18 : 6)
            MiniDock(vertical: option == "left" || option == "right")
                .padding(10)
                .padding(.top, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .id(option)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    // MARK: Recent apps

    private var recents: some View {
        ZStack {
            MiniMenuBar()
            PlaceholderWindow().offset(y: -22)
            MiniDock(extras: isOn ? [.teal, .indigo, .mint] : [])
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 10)
            if isOn {
                Text("Recent")
                    .mini(size: 9, weight: .medium)
                    .foregroundStyle(.white)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 56)
                    .offset(x: 88)
                    .transition(.opacity)
            }
        }
    }

    // MARK: Minimize effect

    private var minimizeEffect: some View {
        Loop(period: 2.4, restingPhase: 0.2) { phase in
            let t = phase < 0.3 ? 0 : min((phase - 0.3) / 0.5, 1)
            let back = ramp(phase, 0.92...1)
            let progress = t - back
            ZStack {
                desktop()
                MiniWindow(title: "Notes", width: 200, height: 120) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(0..<4, id: \.self) { index in
                            Capsule().fill(.primary.opacity(0.12)).frame(width: index == 3 ? 80 : 160, height: 5)
                        }
                    }
                    .padding(12)
                }
                .modifier(MinimizeShape(effect: option ?? "genie", progress: progress))
                .offset(x: 84 * progress, y: -26 + 122 * progress)
                .opacity(progress > 0.92 ? 0 : 1)
            }
        }
    }

    /// An approximation of each minimize effect, enough to tell them apart.
    private struct MinimizeShape: ViewModifier {
        let effect: String
        let progress: Double

        func body(content: Content) -> some View {
            switch effect {
            case "scale":
                content.scaleEffect(1 - 0.88 * progress)
            case "suck":
                // Pulled in by one corner, twisting as it goes.
                content
                    .scaleEffect(x: 1 - 0.9 * pow(progress, 0.6), y: 1 - 0.85 * progress, anchor: .bottomTrailing)
                    .rotationEffect(.degrees(18 * sin(progress * .pi)), anchor: .bottomTrailing)
            default:
                // Genie: the width pinches in first, then the height follows.
                content
                    .scaleEffect(x: 1 - 0.88 * pow(progress, 0.45), y: 1 - 0.85 * pow(progress, 1.6), anchor: .bottom)
            }
        }
    }

    // MARK: Minimize into app icon

    private var minimizeToApp: some View {
        ZStack {
            MiniDock(
                trailing: isOn ? nil : AnyView(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .frame(width: 34, height: 26)
                        .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(.primary.opacity(0.2), lineWidth: 0.5) }
                        .transition(.scale.combined(with: .opacity))
                )
            )
            .overlay(alignment: .bottomLeading) {
                // The running indicator under the app that owns the window.
                Circle().fill(.white).frame(width: 3, height: 3).offset(x: 52, y: 5)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 14)

            StageCaption(text: isOn ? "The window tucks into its app" : "The window gets its own tile")
                .padding(.bottom, 54)
        }
    }

    // MARK: Bounce when opening

    private var launch: some View {
        Loop(period: 1.8, restingPhase: 0) { phase in
            let bounce = isOn ? abs(sin(phase * .pi * 3)) * (1 - phase) * 20 : 0
            ZStack {
            MiniMenuBar()
            MiniDock(lifted: 2, lift: bounce)
                .overlay(alignment: .bottomLeading) {
                    Circle().fill(.white).opacity(phase > 0.15 ? 1 : 0).frame(width: 3, height: 3).offset(x: 85, y: 5)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 14)
            StageCaption(text: isOn ? "The icon bounces while the app opens" : "The app opens without the bounce")
                .padding(.bottom, 70)
            }
        }
    }

    // MARK: Spaces

    private var spaces: some View {
        Loop(period: 3.2, restingPhase: 0) { phase in
            // With the setting on, the Space you just used jumps to the front.
            let moved = isOn ? ramp(phase, 0.35...0.55) - ramp(phase, 0.9...1) : 0
            let order: [Int] = [0, 1, 2]
            VStack(spacing: 14) {
                ZStack {
                    ForEach(order, id: \.self) { index in
                        let slot: Double = switch index {
                        case 2: 2 - 2 * moved
                        default: Double(index) + moved
                        }
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill([Color.blue, .purple, .orange][index].gradient.opacity(0.9))
                                .frame(width: 84, height: 54)
                                .overlay { RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white.opacity(index == 2 ? 0.9 : 0.3), lineWidth: index == 2 ? 1.5 : 0.5) }
                            Text(["Mail", "Design", "Music"][index]).mini(weight: .medium).foregroundStyle(.white)
                        }
                        .offset(x: (slot - 1) * 100)
                        .zIndex(index == 2 ? 1 : 0)
                    }
                }
                Text(isOn ? "The Space you last used moves to the front" : "Your Spaces stay in the order you set")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.35), in: .capsule)
            }
        }
    }
}
