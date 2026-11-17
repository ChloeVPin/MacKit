import MacKitCore
import SwiftUI

struct Sidebar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                row(.home)

                header("App Store")
                row(.discover)
                row(.installed)

                ForEach(TweakCategory.Group.allCases) { group in
                    header(group == .apps ? "App Settings" : group.title)
                    ForEach(group.categories) { category in
                        row(.category(category))
                    }
                }

                Spacer().frame(height: Space.m)
                row(.history)
            }
            .padding(.horizontal, Space.s + 2)
            .padding(.vertical, Space.xs)
        }
        .scrollBounceBehavior(.basedOnSize)
        .focusable()
        .onKeyPress(.upArrow) { move(by: -1) }
        .onKeyPress(.downArrow) { move(by: 1) }
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, Space.s)
            .padding(.top, Space.m + 2)
            .padding(.bottom, 3)
            .accessibilityAddTraits(.isHeader)
    }

    private func row(_ destination: Destination) -> some View {
        SidebarRow(
            destination: destination,
            pending: destination == .installed ? model.store.updateCount : destination.category.map(model.pendingCount(in:)) ?? 0,
            isSelected: model.destination == destination && model.searchText.isEmpty
        ) {
            model.go(to: destination)
        }
    }

    private func move(by offset: Int) -> KeyPress.Result {
        guard let index = Destination.all.firstIndex(of: model.destination) else { return .ignored }
        let next = min(max(index + offset, 0), Destination.all.count - 1)
        model.go(to: Destination.all[next])
        return .handled
    }
}

private struct SidebarRow: View {
    let destination: Destination
    let pending: Int
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isHovered = false

    var body: some View {
        let fillOpacity = isSelected ? (contrast == .increased ? 0.16 : 0.1) : (isHovered ? 0.05 : 0)
        Button(action: action) {
            HStack(spacing: Space.s + 2) {
                Image(systemName: destination.symbol)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(width: 22)
                Text(destination.title)
                    .text(.label)
                    .lineLimit(1)
                Spacer(minLength: Space.xs)
                if pending > 0 {
                    Text(pending, format: .number)
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Color.accentColor, in: .capsule)
                        .contentTransition(.numericText(value: Double(pending)))
                        .transition(reduceMotion ? AnyTransition.opacity : .scale(scale: 0.85).combined(with: .opacity))
                        .accessibilityLabel(destination == .installed ? "\(pending) updates" : "\(pending) pending")
                }
            }
            .padding(.horizontal, Space.s)
            .frame(height: 30)
            .background(
                Color.primary.opacity(fillOpacity),
                in: .rect(cornerRadius: Radius.control, style: .continuous)
            )
            .contentShape(.rect(cornerRadius: Radius.control))
        }
        .buttonStyle(PressableStyle())
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? Motion.fade : Motion.state, value: pending)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension Destination {
    var category: TweakCategory? {
        if case .category(let category) = self { category } else { nil }
    }

    var title: String {
        switch self {
        case .home: "Home"
        case .discover: "Discover"
        case .installed: "Installed"
        case .category(let category): category.title
        case .history: "History"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .discover: "sparkles"
        case .installed: "arrow.down.circle.fill"
        case .category(let category): category.symbol
        case .history: "clock.arrow.circlepath"
        }
    }
}
