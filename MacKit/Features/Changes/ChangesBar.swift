import SwiftUI

/// The floating bar that appears once there's something to apply.
///
/// It's the only custom glass in the app. Glass belongs to things that float
/// above content, and this is the one control that does.
struct ChangesBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let count = model.pending.count

        ZStack {
            if count > 0 {
                bar(count: count)
                    .padding(.bottom, Space.l)
                    .padding(.top, Space.s)
                    .transition(
                        reduceMotion
                            ? AnyTransition.opacity
                            : .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.94, anchor: .bottom))
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? Motion.fade : Motion.surface, value: count > 0)
    }

    private func bar(count: Int) -> some View {
        HStack(spacing: Space.l) {
            Text("\(count) \(count == 1 ? "change" : "changes")")
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(count)))
                .animation(Motion.state, value: count)
                .padding(.leading, Space.m)

            HStack(spacing: Space.s) {
                Button("Discard") {
                    model.discardPending()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Space.s)
                .help("Discard all changes (⌘⌫)")

                Button {
                    model.beginReview()
                } label: {
                    Text("Review")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, Space.s)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .help("Review and apply (⌘↩)")
            }
        }
        .padding(Space.xs + 2)
        .modifier(BarMaterial(reduceTransparency: reduceTransparency, highContrast: contrast == .increased))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pending changes")
    }
}

private struct BarMaterial: ViewModifier {
    let reduceTransparency: Bool
    let highContrast: Bool

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Color(nsColor: .controlBackgroundColor), in: .capsule)
                .overlay { Capsule().strokeBorder(.primary.opacity(highContrast ? 0.35 : 0.16), lineWidth: 1) }
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        } else {
            content
                .glassEffect(.regular, in: .capsule)
        }
    }
}
