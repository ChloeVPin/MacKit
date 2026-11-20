import MacKitCore
import SwiftUI

/// The first screen: this Mac, and a few good places to start.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [GridItem(.adaptive(minimum: 250), spacing: Space.m, alignment: .top)]

    var body: some View {
        Page {
            hero
                .padding(.top, Space.s)
                .padding(.bottom, Space.s)

            VStack(alignment: .leading, spacing: Space.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick Setups")
                        .font(.system(size: 17, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Pick a starting point. Nothing changes until you review it.")
                        .text(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, Space.xs)

                LazyVGrid(columns: columns, spacing: Space.m) {
                    ForEach(QuickSetup.all) { setup in
                        SetupCard(setup: setup)
                    }
                }
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        HStack(alignment: .center, spacing: Space.xl) {
            Image(nsImage: NSImage(named: NSImage.computerName) ?? NSImage())
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 112, height: 112)
                .background {
                    // A soft glow in the brand color, so the Mac sits in
                    // light instead of on a blank page.
                    Ellipse()
                        .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1))
                        .frame(width: 190, height: 150)
                        .blur(radius: 44)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Space.xs) {
                Text(model.machine?.model ?? "Your Mac")
                    .text(.hero)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.opacity)
                Text(specs)
                    .text(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)

                Text(summary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Space.s + 2)
                    .padding(.vertical, Space.xs + 1)
                    .background(.card, in: .capsule)
                    .overlay { Capsule().strokeBorder(.cardBorder) }
                    .padding(.top, Space.s)
                    .contentTransition(.numericText())
            }
            .animation(Motion.fade, value: model.machine)
            .animation(Motion.state, value: model.customizedCount)
            .accessibilityElement(children: .combine)
        }
    }

    private var specs: String {
        guard let machine = model.machine else { return " " }
        return [machine.chip, machine.memory, "macOS \(machine.systemVersion)"]
            .filter { !$0.isEmpty }
            .joined(separator: "  ·  ")
    }

    private var summary: String {
        guard model.isLoaded else { return "Reading settings…" }
        let count = model.customizedCount
        if count == 0 { return "All \(model.tweaks.count) settings at their defaults" }
        return "\(count) of \(model.tweaks.count) settings customized"
    }
}

/// One quick setup: what it's for, and a single click to select it.
private struct SetupCard: View {
    let setup: QuickSetup

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isHovered = false

    var body: some View {
        let status = model.status(of: setup)
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        let restingBorder = contrast == .increased ? 0.28 : 0.06

        Button {
            withAnimation(reduceMotion ? Motion.fade : Motion.state) { model.toggle(setup) }
        } label: {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(alignment: .top) {
                    IconTile(symbol: setup.category.symbol, size: 32)
                    Spacer()
                    if model.isLoaded {
                        statusBadge(status)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(setup.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(setup.summary)
                        .text(.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(Layout.cardInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected(status) ? AnyShapeStyle(Color.accentColor.opacity(0.1)) : AnyShapeStyle(.card), in: shape)
            .overlay {
                shape.strokeBorder(
                    isSelected(status)
                        ? AnyShapeStyle(Color.accentColor.opacity(0.55))
                        : AnyShapeStyle(Color.primary.opacity(isHovered ? max(restingBorder, 0.14) : restingBorder)),
                    lineWidth: isSelected(status) ? 1.5 : 1
                )
            }
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        // Until the Mac has been read, every setting looks unset, so the
        // counts would be wrong and a click could select settings that are
        // already in place.
        .disabled(status == .alreadySet || !model.isLoaded)
        .onHover { isHovered = $0 }
        .animation(Motion.fade, value: isHovered)
        .accessibilityLabel("\(setup.title). \(setup.summary)")
        .accessibilityValue(model.isLoaded ? accessibilityValue(status) : "")
    }

    private func isSelected(_ status: AppModel.SetupStatus) -> Bool {
        if case .selected = status { true } else { false }
    }

    @ViewBuilder
    private func statusBadge(_ status: AppModel.SetupStatus) -> some View {
        switch status {
        case .alreadySet:
            Label("Already set", systemImage: "checkmark")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        case .selected:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.accentColor)
                .transition(reduceMotion ? AnyTransition.opacity : .scale(scale: 0.85).combined(with: .opacity))
        case .available(let changes):
            Text(Self.changes(changes))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Space.s)
                .padding(.vertical, 3)
                .background(.primary.opacity(0.06), in: .capsule)
        }
    }

    private func accessibilityValue(_ status: AppModel.SetupStatus) -> String {
        switch status {
        case .alreadySet: "Already set"
        case .selected(let changes): "Selected, \(Self.changes(changes))"
        case .available(let changes): Self.changes(changes)
        }
    }

    private static func changes(_ count: Int) -> String {
        "\(count) \(count == 1 ? "change" : "changes")"
    }
}
