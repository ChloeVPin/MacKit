import MacKitCore
import SwiftUI

/// One setting in a card: its name, a sentence about it, and a native
/// control. In a list, clicking the row opens the setting's own page.
struct TweakRow: View {
    enum Style {
        /// A row among others. Clicking it opens the detail page.
        case list
        /// The single row at the top of a detail page.
        case detail
    }

    let tweak: Tweak
    var style: Style = .list

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        let isPending = model.isPending(tweak)

        HStack(alignment: .center, spacing: Space.m) {
            if style == .list {
                Button {
                    model.open(tweak)
                } label: {
                    titleBlock
                }
                .buttonStyle(.plain)
                .contentShape(.rect)
                .layoutPriority(1)
                .accessibilityHint("Shows details and commands for this setting.")
            } else {
                titleBlock
                    .layoutPriority(1)
            }

            if isPending {
                Button {
                    model.clearPending(tweak)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 22, height: 22)
                        .background(Color.accentColor.opacity(0.14), in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(PressableStyle())
                .help("Undo this change")
                .accessibilityLabel("Undo change to \(tweak.title)")
                .transition(reduceMotion ? AnyTransition.opacity : .scale(scale: 0.85).combined(with: .opacity))
            }

            control
                .disabled(model.isLocked(tweak))

            if style == .list {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .contentShape(.rect)
                    .onTapGesture { model.open(tweak) }
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Layout.cardInset)
        .padding(.vertical, Space.s + 2)
        .frame(minHeight: style == .detail ? 54 : 46)
        .background(style == .list && isHovered ? Color.rowHover : Color.clear)
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .onTapGesture {
            if style == .list { model.open(tweak) }
        }
        .animation(reduceMotion ? Motion.fade : Motion.state, value: isPending)
        .contextMenu {
            if isPending {
                Button("Undo This Change") { model.clearPending(tweak) }
            }
            if let stock = tweak.stockOption, tweak.hasDefault, model.selectedOption(for: tweak) != stock.id {
                Button("Reset to Default (\(stock.label))") {
                    model.select(tweak.stockOptionID, for: tweak)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Show Details") { model.open(tweak) }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Space.xs + 1) {
                Text(tweak.title)
                    .font(.system(size: 13, weight: style == .detail ? .semibold : .regular))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if tweak.requiresAdministrator {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .help("Needs an administrator password")
                        .accessibilityLabel("Needs an administrator password")
                }
            }
            Text(tweak.summary)
                .text(.detail)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessibilityHintText: String {
        var parts = [tweak.summary]
        if tweak.requiresAdministrator { parts.append("Needs an administrator password.") }
        if let caution = tweak.caution { parts.append(caution) }
        return parts.joined(separator: " ")
    }

    @ViewBuilder private var control: some View {
        if case .number(let input)? = tweak.input {
            NumberControl(tweak: tweak, input: input, hint: accessibilityHintText)
        } else if case .text(let input)? = tweak.input {
            TextControl(tweak: tweak, input: input, hint: accessibilityHintText)
        } else if tweak.isToggle {
            HStack(spacing: Space.s) {
                if model.selectedOption(for: tweak) == nil, case .custom = model.state(of: tweak) {
                    Text("Custom")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Space.s - 1)
                        .padding(.vertical, 2)
                        .background(.card, in: .capsule)
                        .overlay { Capsule().strokeBorder(.cardBorder) }
                }
                Toggle(tweak.title, isOn: Binding(
                    get: { model.selectedOption(for: tweak) == TweakOption.on.id },
                    set: { model.select($0 ? TweakOption.on.id : TweakOption.off.id, for: tweak) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .accessibilityHint(accessibilityHintText)
            }
        } else {
            let selection = model.selectedOption(for: tweak)
            Picker(tweak.title, selection: Binding(
                get: { selection ?? Self.customTag },
                set: { if $0 != Self.customTag { model.select($0, for: tweak) } }
            )) {
                if selection == nil {
                    // The Mac holds a value that isn't one of MacKit's options.
                    Text(model.label(for: model.state(of: tweak), of: tweak)).tag(Self.customTag)
                    Divider()
                }
                ForEach(tweak.options) { option in
                    Text(option.label).tag(option.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .accessibilityLabel(tweak.title)
            .accessibilityHint(accessibilityHintText)
            // As wide as its value needs, up to a limit. Past that the menu
            // truncates instead of running over the setting's name.
            .frame(maxWidth: 190, alignment: .trailing)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private static let customTag = "__custom"
}

/// A slider with its value beside it.
private struct NumberControl: View {
    let tweak: Tweak
    let input: NumberInput
    let hint: String

    @Environment(AppModel.self) private var model
    /// Where the thumb is while it's being dragged. The setting only takes
    /// stepped values, and feeding those straight back to the slider makes
    /// the thumb jump from step to step behind the pointer.
    @State private var dragged: Double?
    @State private var isDragging = false

    var body: some View {
        let stored = model.number(for: tweak, input)
        let shown = dragged.map(input.snapped) ?? stored
        HStack(spacing: Space.s) {
            // No `step`: SwiftUI draws a tick for every step, which turns a
            // fine-grained slider into a comb. The model snaps instead.
            Slider(
                value: Binding(
                    get: { dragged ?? stored },
                    set: { new in
                        let previous = dragged.map(input.snapped) ?? stored
                        dragged = new
                        // Only tell the model when the stepped value moves on.
                        if input.snapped(new) != previous { model.setNumber(new, for: tweak, input) }
                    }
                ),
                in: input.range,
                onEditingChanged: { isEditing in
                    isDragging = isEditing
                    if !isEditing { dragged = nil }
                }
            )
            // Arrow keys and Undo change the value without a drag.
            .onChange(of: stored) {
                if !isDragging { dragged = nil }
            }
            .frame(width: 130)
            .accessibilityLabel(tweak.title)
            .accessibilityValue(input.label(for: shown))
            .accessibilityHint(hint)

            // No digit animation: while dragging, the numbers change faster
            // than a transition can finish and smear into each other.
            Text(input.label(for: shown))
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }
}

/// A text field that marks a change as you type.
private struct TextControl: View {
    let tweak: Tweak
    let input: TextInput
    let hint: String

    @Environment(AppModel.self) private var model
    @State private var draft = ""

    var body: some View {
        let current = model.text(for: tweak)
        TextField(input.placeholder, text: $draft)
            .textFieldStyle(.roundedBorder)
            .frame(width: 200)
            .accessibilityLabel(tweak.title)
            .accessibilityHint(hint)
            .onAppear { draft = current }
            .onChange(of: draft) { _, typed in
                let cleaned = input.cleaned(typed)
                if cleaned != typed { draft = cleaned }
                if cleaned != model.text(for: tweak) { model.setText(cleaned, for: tweak, input) }
            }
            // Undo, Discard, and Reset change the value from outside.
            .onChange(of: current) { _, value in
                if value != draft, !(value.isEmpty && !tweak.hasDefault) { draft = value }
            }
    }
}

/// Tweaks grouped under their section headings, each group in a card.
struct TweakSections: View {
    let tweaks: [Tweak]
    /// Shown above each section name, for lists that mix categories.
    var showsCategory = false

    var body: some View {
        ForEach(groups, id: \.id) { group in
            CardSection(title: group.title) {
                ForEach(Array(group.tweaks.enumerated()), id: \.element.id) { index, tweak in
                    if index > 0 { RowDivider() }
                    TweakRow(tweak: tweak)
                }
            }
        }
    }

    private struct Group {
        let id: String
        let title: String
        var tweaks: [Tweak]
    }

    /// Tweaks grouped by category and section, preserving the rank of the
    /// first matching setting in each group.
    private var groups: [Group] {
        var groups: [Group] = []
        var indexByID: [String: Int] = [:]
        for tweak in tweaks {
            let id = "\(tweak.category.rawValue)/\(tweak.section)"
            if let existing = indexByID[id] {
                groups[existing].tweaks.append(tweak)
            } else {
                let title = showsCategory ? ChangeWording.location(category: tweak.category, section: tweak.section) : tweak.section
                indexByID[id] = groups.count
                groups.append(Group(id: id, title: title, tweaks: [tweak]))
            }
        }
        return groups
    }
}
