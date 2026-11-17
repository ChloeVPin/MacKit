import MacKitCore
import SwiftUI

/// The last stop before anything is written: every change in plain words,
/// what happens afterward, and the commands for anyone who asks.
struct ReviewSheet: View {
    let session: ReviewSession

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsCommands = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding([.horizontal, .top], Space.xl)
                .padding(.bottom, Space.l)

            ViewThatFits(in: .vertical) {
                changeList
                ScrollView { changeList }
                    .scrollEdgeEffectStyle(.soft, for: .all)
            }
            .frame(maxHeight: 340)

            if session.phase == .reviewing, !notes.isEmpty {
                VStack(alignment: .leading, spacing: Space.s - 2) {
                    ForEach(notes, id: \.text) { note in
                        Label(note.text, systemImage: note.symbol)
                            .text(.detail)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, Space.xl + Space.xs)
                .padding(.top, Space.l)
                .transition(.opacity)
            }

            footer
                .padding(Space.xl)
        }
        .frame(width: 480)
        .interactiveDismissDisabled(session.phase == .running)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: Space.m) {
            if session.phase == .finished {
                let succeeded = session.failedCount == 0
                Image(systemName: succeeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 34))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(succeeded ? .green : .orange)
                    .symbolEffect(.bounce, options: .nonRepeating, isActive: !reduceMotion)
                    .transition(reduceMotion ? AnyTransition.opacity : .scale(scale: 0.5).combined(with: .opacity))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(headline)
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.3)
                Text(subhead)
                    .text(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentTransition(.opacity)
        }
    }

    private var headline: String {
        let count = session.rows.count
        let noun = count == 1 ? "change" : "changes"
        switch session.phase {
        case .reviewing:
            return session.kind.isUndo ? "Undo \(count) \(noun)?" : "Apply \(count) \(noun)?"
        case .running:
            return session.kind.isUndo ? "Undoing…" : "Applying…"
        case .finished:
            let applied = session.appliedCount
            let failed = session.failedCount
            let verb = session.kind.isUndo ? "undone" : "applied"
            if failed == 0 { return "\(applied) \(applied == 1 ? "change" : "changes") \(verb)" }
            if applied == 0 { return "Nothing was changed" }
            return "\(applied) \(verb), \(failed) didn't go through"
        }
    }

    private var subhead: String {
        switch session.phase {
        case .reviewing:
            session.kind.isUndo
                ? "Each setting goes back to what it was before."
                : "Nothing changes until you click Apply."
        case .running:
            "This only takes a moment."
        case .finished:
            if session.failedCount > 0 {
                "The ones that didn't go through were left as they were."
            } else if session.kind.isUndo {
                "Everything is back the way it was."
            } else {
                "You can undo any of these in History."
            }
        }
    }

    // MARK: Changes

    private var changeList: some View {
        Card {
            ForEach(Array(session.rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { RowDivider() }
                ReviewRow(row: row, progress: session.progress[row.id], showsCommands: showsCommands)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.vertical, 1)
    }

    // MARK: Notes

    private struct Note {
        let symbol: String
        let text: String
    }

    private var notes: [Note] {
        let plan = session.plan
        var notes: [Note] = []
        if plan.privilegedChangeCount > 0 {
            notes.append(Note(symbol: "lock", text: "You'll be asked for an administrator password."))
        }
        if !plan.restarts.isEmpty {
            let names = plan.restarts.map(\.displayName).formatted(.list(type: .and))
            notes.append(Note(symbol: "arrow.clockwise", text: "\(names.prefix(1).capitalized + names.dropFirst()) will restart. It takes about a second."))
        }
        if plan.needsAppRelaunch {
            notes.append(Note(symbol: "macwindow", text: "Some changes show up the next time each app opens."))
        }
        if plan.needsLogout {
            notes.append(Note(symbol: "person.crop.circle", text: "Some changes apply after you log out and back in."))
        }
        if plan.changes.contains(where: { $0.tweak.effect == .restart || $0.tweak.effect == .nextStartup }) {
            notes.append(Note(symbol: "power", text: "Some changes apply after this Mac restarts."))
        }
        // A setting's warning matters when moving away from how macOS ships,
        // not when putting it back.
        for change in plan.changes {
            guard let caution = change.tweak.caution, change.target != .option(change.tweak.stockOptionID) else { continue }
            notes.append(Note(symbol: "exclamationmark.triangle", text: "\(change.tweak.title): \(caution)"))
        }
        return notes
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: Space.s) {
            if session.phase == .reviewing {
                Button(showsCommands ? "Hide Commands" : "Show Commands") {
                    withAnimation(reduceMotion ? Motion.fade : Motion.surface) { showsCommands.toggle() }
                }
                .buttonStyle(QuietLinkStyle())
                .help("Show the Terminal command behind each change")
            }
            Spacer()
            switch session.phase {
            case .reviewing, .running:
                Button("Cancel", role: .cancel) {
                    model.review = nil
                }
                .keyboardShortcut(.cancelAction)
                .disabled(session.phase == .running)

                Button {
                    Task { await model.runReview() }
                } label: {
                    Text(session.kind.isUndo ? "Undo" : "Apply")
                        .frame(minWidth: 64)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(session.phase == .running)

            case .finished:
                Button {
                    model.review = nil
                } label: {
                    Text("Done")
                        .frame(minWidth: 64)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
    }
}

private struct ReviewRow: View {
    let row: ReviewSession.Row
    let progress: ChangeProgress?
    let showsCommands: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tweak = row.change.tweak

        HStack(alignment: .center, spacing: Space.m) {
            IconTile(symbol: tweak.category.symbol, size: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(tweak.title)
                    .text(.label)
                    .lineLimit(2)
                if case .finished(.failed(let error)) = progress {
                    Text(error.explanation)
                        .text(.detail)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else if showsCommands {
                    ForEach(row.change.operations, id: \.self) { operation in
                        Text(operation.commandText)
                            .text(.code)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(ChangeWording.location(category: tweak.category, section: tweak.section))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            trailing
        }
        .padding(.horizontal, Layout.cardInset)
        .padding(.vertical, Space.s + 1)
        .frame(minHeight: 42)
        .accessibilityElement(children: showsCommands ? .contain : .combine)
    }

    @ViewBuilder private var trailing: some View {
        switch progress {
        case nil:
            Text(ChangeWording.action(from: row.from, to: row.to))
                .text(.label)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 165, alignment: .trailing)
                .fixedSize(horizontal: true, vertical: false)
        case .running:
            ProgressView()
                .controlSize(.small)
        case .finished(.applied):
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.green)
                .transition(reduceMotion ? AnyTransition.opacity : .scale(scale: 0.85).combined(with: .opacity))
                .accessibilityLabel("Done")
        case .finished(.failed):
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
                .transition(reduceMotion ? AnyTransition.opacity : .scale(scale: 0.85).combined(with: .opacity))
                .accessibilityLabel("Didn't go through")
        }
    }
}
