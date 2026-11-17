import SwiftUI

// The pieces every setting preview is built from: a wallpaper stage, a
// miniature window, a miniature Dock, and a clock for previews that loop.
//
// Previews are drawn, not recorded. That keeps them sharp at any size,
// correct in light and dark, and able to respond the instant a control
// changes.

/// The framed area a preview is drawn in.
struct PreviewStage<Content: View>: View {
    @ViewBuilder var content: Content

    static var height: CGFloat { 268 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        ZStack {
            Wallpaper()
            content
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .clipShape(shape)
        .overlay { shape.strokeBorder(.primary.opacity(0.1), lineWidth: 1) }
        .accessibilityHidden(true)
    }
}

/// A soft abstract desktop picture, so previews sit on something that reads
/// as a Mac's desktop without imitating a real wallpaper.
struct Wallpaper: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.55], [0.6, 0.4], [1, 0.5],
                [0, 1], [0.45, 1], [1, 1],
            ],
            colors: dark
                ? [
                    Color(red: 0.10, green: 0.12, blue: 0.24), Color(red: 0.16, green: 0.14, blue: 0.32), Color(red: 0.30, green: 0.16, blue: 0.30),
                    Color(red: 0.08, green: 0.16, blue: 0.30), Color(red: 0.22, green: 0.18, blue: 0.40), Color(red: 0.46, green: 0.22, blue: 0.24),
                    Color(red: 0.06, green: 0.10, blue: 0.20), Color(red: 0.14, green: 0.14, blue: 0.30), Color(red: 0.36, green: 0.20, blue: 0.16),
                ]
                : [
                    Color(red: 0.72, green: 0.82, blue: 0.98), Color(red: 0.80, green: 0.80, blue: 0.98), Color(red: 0.96, green: 0.80, blue: 0.86),
                    Color(red: 0.66, green: 0.84, blue: 0.96), Color(red: 0.84, green: 0.82, blue: 0.98), Color(red: 1.00, green: 0.82, blue: 0.72),
                    Color(red: 0.74, green: 0.86, blue: 0.98), Color(red: 0.86, green: 0.86, blue: 0.98), Color(red: 1.00, green: 0.86, blue: 0.70),
                ]
        )
    }
}

/// A small window with a title bar and traffic lights.
struct MiniWindow<Content: View>: View {
    var title = ""
    var width: CGFloat = 380
    var height: CGFloat = 204
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 5) {
                    ForEach([Color.red, .yellow, .green], id: \.self) { color in
                        Circle().fill(color.opacity(0.85)).frame(width: 7, height: 7)
                    }
                    Spacer()
                }
                Text(title).mini(weight: .semibold)
            }
            .padding(.horizontal, 9)
            .frame(height: 24)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: width, height: height)
        .background(Color(nsColor: .windowBackgroundColor), in: shape)
        .clipShape(shape)
        .overlay { shape.strokeBorder(.primary.opacity(0.12), lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.22), radius: 14, y: 7)
    }
}

/// A floating panel inside a preview: an alert, a dialog, a popover.
struct MiniPanel<Content: View>: View {
    var width: CGFloat = 200
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        content
            .padding(12)
            .frame(width: width)
            .background(Color(nsColor: .windowBackgroundColor), in: shape)
            .overlay { shape.strokeBorder(.primary.opacity(0.12), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }
}

/// A pretend button inside a preview.
struct MiniButton: View {
    let title: String
    var prominent = false

    var body: some View {
        Text(title)
            .mini(weight: .medium)
            .foregroundStyle(prominent ? .white : .primary)
            .frame(maxWidth: .infinity)
            .frame(height: 18)
            .background(prominent ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary.opacity(0.1)), in: .rect(cornerRadius: 5))
    }
}

/// A miniature Dock.
struct MiniDock: View {
    static let apps: [Color] = [.blue, .green, .orange, .pink, .purple]

    var vertical = false
    var extras: [Color] = []
    /// Index of an app icon to lift, for launch animations.
    var lifted: Int?
    var lift: CGFloat = 0
    var trailing: AnyView?

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 5)) : AnyLayout(HStackLayout(spacing: 5))
        layout {
            ForEach(Array(Self.apps.enumerated()), id: \.offset) { index, color in
                icon(color)
                    .offset(x: vertical && lifted == index ? lift : 0, y: !vertical && lifted == index ? -lift : 0)
            }
            if !extras.isEmpty || trailing != nil {
                Rectangle().fill(.white.opacity(0.4))
                    .frame(width: vertical ? 16 : 1, height: vertical ? 1 : 16)
            }
            ForEach(Array(extras.enumerated()), id: \.offset) { _, color in
                icon(color).transition(.scale.combined(with: .opacity))
            }
            if let trailing { trailing }
        }
        .padding(7)
        .background(.white.opacity(0.28), in: .rect(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 0.5) }
    }

    private func icon(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(color.gradient)
            .frame(width: 28, height: 28)
    }
}

/// The strip across the top of a desktop scene.
struct MiniMenuBar: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "apple.logo").font(.system(size: 9))
            ForEach(["Finder", "File", "Edit", "View"], id: \.self) { title in
                Text(title).mini(size: 9, weight: title == "Finder" ? .semibold : .regular)
            }
            Spacer()
            Image(systemName: "wifi").font(.system(size: 8))
            Text("9:41").mini(size: 9)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(height: 18)
        .background(.black.opacity(0.12))
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// A plain window to give a desktop scene something on it.
struct PlaceholderWindow: View {
    var title = "Notes"
    var width: CGFloat = 230
    var height: CGFloat = 132

    var body: some View {
        MiniWindow(title: title, width: width, height: height) {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule().fill(.primary.opacity(0.12)).frame(width: index == 3 ? width * 0.4 : width * 0.8, height: 5)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Drives a preview that repeats. `content` receives the position in the
/// current cycle, from 0 up to 1. With Reduce Motion on, the preview holds
/// still at `restingPhase`.
struct Loop<Content: View>: View {
    let period: Double
    var restingPhase: Double = 0.6
    @ViewBuilder var content: (Double) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            content(restingPhase)
        } else {
            TimelineView(.animation) { context in
                content(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period)
            }
        }
    }
}

/// Maps a phase in `range` to 0...1, clamped, with an ease-out.
func ramp(_ phase: Double, _ range: ClosedRange<Double>) -> Double {
    guard range.upperBound > range.lowerBound else { return phase >= range.upperBound ? 1 : 0 }
    let t = min(max((phase - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    return 1 - pow(1 - t, 3)
}

extension View {
    /// The small text used inside previews.
    func mini(size: CGFloat = 9.5, weight: Font.Weight = .regular) -> some View {
        font(.system(size: size, weight: weight)).lineLimit(1)
    }
}

/// A small caption pinned to the bottom of a stage, for previews that need
/// a word of explanation.
struct StageCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(.black.opacity(0.35), in: .capsule)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 10)
            .contentTransition(.opacity)
    }
}
