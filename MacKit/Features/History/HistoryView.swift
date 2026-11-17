import MacKitCore
import SwiftUI

/// Every batch MacKit has applied, newest first, each one undoable.
struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let records = model.history

        Page {
            PageHeader(
                symbol: Destination.history.symbol,
                title: "History",
                subtitle: "Everything MacKit has changed on this Mac."
            )

            if records.isEmpty {
                EmptyState(
                    symbol: "clock.arrow.circlepath",
                    title: "No changes yet",
                    message: "Changes you apply are kept here with the value they replaced, so you can always undo them."
                )
            } else {
                ForEach(records) { record in
                    RecordSection(record: record)
                }
            }
        }
    }
}

private struct RecordSection: View {
    let record: HistoryRecord

    @Environment(AppModel.self) private var model

    var body: some View {
        let undoable = record.entries.filter { $0.canRevert && model.tweak($0.tweakID) != nil }

        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(dateText)
                    .text(.heading)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if undoable.count > 1 {
                    Button("Undo All") {
                        model.beginUndo(of: undoable, in: record)
                    }
                    .buttonStyle(QuietLinkStyle())
                    .accessibilityLabel("Undo all changes from \(dateText)")
                }
            }
            .padding(.horizontal, Space.xs)

            Card {
                ForEach(Array(record.entries.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { RowDivider() }
                    EntryRow(entry: entry, record: record)
                }
            }
        }
    }

    private var dateText: String {
        let calendar = Calendar.current
        let time = record.date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(record.date) { return "Today at \(time)" }
        if calendar.isDateInYesterday(record.date) { return "Yesterday at \(time)" }
        return record.date.formatted(.dateTime.weekday(.wide).month(.wide).day()) + " at \(time)"
    }
}

private struct EntryRow: View {
    let entry: HistoryEntry
    let record: HistoryRecord

    @Environment(AppModel.self) private var model

    var body: some View {
        let isUndone = entry.revertedAt != nil

        HStack(alignment: .center, spacing: Space.m) {
            IconTile(symbol: entry.category.symbol, size: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .text(.label)
                    .lineLimit(2)
                Text(detailLine)
                    .text(.detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Group {
                if isUndone {
                    Text("Undone")
                        .text(.detail)
                        .foregroundStyle(.secondary)
                } else if entry.canRevert, model.tweak(entry.tweakID) != nil {
                    Button("Undo") {
                        model.beginUndo(of: [entry], in: record)
                    }
                    .controlSize(.small)
                    .accessibilityLabel("Undo \(entry.title)")
                } else {
                    Text("Can't undo")
                        .text(.detail)
                        .foregroundStyle(.tertiary)
                        .help("MacKit couldn't read this setting's earlier value, so there's nothing exact to put back.")
                }
            }
            // The text column takes priority, so anything trailing has to
            // insist on its own width or it gets squeezed to nothing.
            .fixedSize()
        }
        .opacity(isUndone ? 0.55 : 1)
        .padding(.horizontal, Layout.cardInset)
        .padding(.vertical, Space.s + 1)
        .frame(minHeight: 46)
    }

    private var detailLine: String {
        let section = entry.section ?? model.tweak(entry.tweakID)?.section
        let location = ChangeWording.location(category: entry.category, section: section)
        return "\(location) · \(ChangeWording.past(from: entry.from, to: entry.to))"
    }
}
