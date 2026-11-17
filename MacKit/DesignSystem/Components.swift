import MacKitCore
import SwiftUI

/// A quiet, neutral tile holding a symbol. It gives a page or a row a face
/// without adding color, so the accent stays the only color in the window.
struct IconTile: View {
    let symbol: String
    var size: CGFloat = 22

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .medium))
            .foregroundStyle(.primary.opacity(0.85))
            .frame(width: size, height: size)
            .background(.primary.opacity(0.07), in: shape)
            .overlay { shape.strokeBorder(.primary.opacity(0.08), lineWidth: 1) }
            .accessibilityHidden(true)
    }
}

extension TweakCategory {
    var symbol: String {
        switch self {
        case .finder: "folder.fill"
        case .desktop: "menubar.dock.rectangle"
        case .dock: "dock.rectangle"
        case .missionControl: "rectangle.3.group.fill"
        case .windows: "macwindow"
        case .appearance: "paintpalette.fill"
        case .menuBar: "menubar.rectangle"
        case .sound: "speaker.wave.2.fill"
        case .keyboard: "keyboard.fill"
        case .trackpad: "hand.point.up.left.fill"
        case .screenshots: "camera.viewfinder"
        case .apps: "square.grid.2x2.fill"
        case .accessibility: "accessibility"
        case .power: "battery.75percent"
        case .sharing: "network"
        case .security: "lock.shield.fill"
        case .updates: "arrow.triangle.2.circlepath"
        case .system: "power"
        }
    }
}

/// A grouped surface that holds rows, like a section in System Settings.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        let isHighContrast = contrast == .increased
        VStack(spacing: 0) {
            content
        }
        .background(Color.primary.opacity(isHighContrast ? 0.065 : 0.045), in: shape)
        .overlay { shape.strokeBorder(Color.primary.opacity(isHighContrast ? 0.28 : 0.06), lineWidth: 1) }
        .clipShape(shape)
    }
}

/// The hairline between two rows in a card.
struct RowDivider: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Rectangle()
            .fill(.primary.opacity(contrast == .increased ? 0.22 : 0.08))
            .frame(height: 1)
            .padding(.leading, Layout.cardInset)
    }
}

/// A heading with its card of rows beneath it.
struct CardSection<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if let title {
                Text(title)
                    .text(.heading)
                    .padding(.leading, Space.xs)
                    .accessibilityAddTraits(.isHeader)
            }
            Card { content }
        }
    }
}

/// One choice in a row of filters: a capsule that fills in when selected.
struct Chip: View {
    let title: String
    var count: Int?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let borderOpacity = contrast == .increased ? 0.28 : 0.06
        Button(action: action) {
            HStack(spacing: Space.xs + 1) {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                if let count {
                    Text(count, format: .number)
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .opacity(0.6)
                }
            }
            .foregroundStyle(isSelected ? Color(nsColor: .windowBackgroundColor) : .primary)
            .padding(.horizontal, Space.m)
            .frame(height: 26)
            .background(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.card), in: .capsule)
            .overlay { Capsule().strokeBorder(.primary.opacity(borderOpacity), lineWidth: isSelected ? 0 : 1) }
            .contentShape(.capsule)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(count.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A row of chips under a page header. Scrolls sideways when it's long.
struct ChipBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Space.xs + 2) { content }
                .padding(.vertical, 1)
                .padding(.trailing, Space.l)
        }
        .scrollIndicators(.never)
        .mask {
            HStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: Space.l)
            }
        }
        .padding(.top, -Space.s)
    }
}

/// A spinner in the middle of a page whose content isn't ready yet.
struct PageLoading: View {
    let label: String

    var body: some View {
        ProgressView()
            .controlSize(.regular)
            .frame(maxWidth: .infinity, minHeight: 320)
            .accessibilityLabel(label)
    }
}

/// Scales down slightly while pressed, so a click is felt on mouse-down.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// A small text button for secondary actions. Neutral, so the accent stays
/// reserved for the primary action and for pending changes.
struct QuietLinkStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(isHovered || configuration.isPressed ? .primary : .secondary)
            .contentShape(.rect)
            .onHover { isHovered = $0 }
            .animation(Motion.fade, value: isHovered)
    }
}

/// The standard page: a centered column that scrolls under the toolbar.
struct Page<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Space.xl + Space.xs) {
                content
            }
            .frame(maxWidth: Layout.contentWidth, alignment: .leading)
            .padding(.horizontal, Layout.pageInset)
            .padding(.top, Space.s)
            .padding(.bottom, Space.xxxl)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
    }
}

/// The title block at the top of a page.
struct PageHeader<Accessory: View>: View {
    let symbol: String
    let title: String
    let subtitle: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: Space.l) {
            IconTile(symbol: symbol, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .text(.title)
                    .lineLimit(2)
                Text(subtitle)
                    .text(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            accessory
        }
        .padding(.bottom, Space.xs)
    }
}

extension PageHeader where Accessory == EmptyView {
    init(symbol: String, title: String, subtitle: String) {
        self.init(symbol: symbol, title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// A centered message for a page that has nothing to show yet.
struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Space.s) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.tertiary)
                .padding(.bottom, Space.xs)
            Text(title)
                .font(.system(size: 17, weight: .semibold))
            Text(message)
                .text(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xxxl)
        .accessibilityElement(children: .combine)
    }
}

/// A round "…" button that opens a menu directly beneath itself.
///
/// SwiftUI's `Menu` reserves room for an indicator even when it's hidden,
/// which pushes the icon off center, and it places the menu loosely. This
/// draws the button itself and asks AppKit to open the menu from its
/// bottom-left corner.
struct MoreButton: View {
    struct Item {
        let title: String
        var isEnabled = true
        let action: () -> Void
    }

    let items: [Item]

    @Environment(\.colorSchemeContrast) private var contrast
    @State private var anchor = MenuAnchor()

    var body: some View {
        Button {
            anchor.show(items)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.card, in: .circle)
                .overlay { Circle().strokeBorder(.primary.opacity(contrast == .increased ? 0.28 : 0.06)) }
                .contentShape(.circle)
        }
        .buttonStyle(PressableStyle())
        .background { MenuAnchorView(anchor: anchor) }
        .help("More")
        .accessibilityLabel("More")
    }
}

/// Holds the AppKit view a menu opens from.
@MainActor
private final class MenuAnchor {
    weak var view: NSView?
    private var handlers: [MenuHandler] = []

    func show(_ items: [MoreButton.Item]) {
        guard let view else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false
        handlers = items.map { MenuHandler(action: $0.action) }
        for (item, handler) in zip(items, handlers) {
            let entry = NSMenuItem(title: item.title, action: #selector(MenuHandler.run), keyEquivalent: "")
            entry.target = handler
            entry.isEnabled = item.isEnabled
            menu.addItem(entry)
        }
        // Just under the button, lined up with its left edge.
        let origin = NSPoint(x: 0, y: view.isFlipped ? view.bounds.maxY + 6 : -6)
        menu.popUp(positioning: nil, at: origin, in: view)
    }
}

private final class MenuHandler: NSObject {
    let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    @objc func run() { action() }
}

private struct MenuAnchorView: NSViewRepresentable {
    let anchor: MenuAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        anchor.view = view
    }
}
