import MacKitCore
import Observation
import SwiftUI

/// One trip through the review sheet: a fixed plan, then its progress.
@Observable
final class ReviewSession: Identifiable {
    enum Kind {
        case apply
        /// Undoing entries of an earlier batch. `entryIDs` maps each tweak in
        /// the plan to the history entry it undoes.
        case undo(recordID: UUID, entryIDs: [Tweak.ID: UUID])

        var isUndo: Bool {
            if case .undo = self { true } else { false }
        }
    }

    enum Phase {
        case reviewing
        case running
        case finished
    }

    struct Row: Identifiable {
        let change: PlannedChange
        /// The value now, as shown to the user.
        let from: String
        /// The value after the change.
        let to: String

        var id: Tweak.ID { change.id }
    }

    let id = UUID()
    let kind: Kind
    let plan: ChangePlan
    let rows: [Row]
    var phase: Phase = .reviewing
    var progress: [Tweak.ID: ChangeProgress] = [:]

    init(kind: Kind, plan: ChangePlan, rows: [Row]) {
        self.kind = kind
        self.plan = plan
        self.rows = rows
    }

    var appliedCount: Int {
        progress.values.count { $0 == .finished(.applied) }
    }

    var failedCount: Int {
        progress.values.count {
            if case .finished(.failed) = $0 { true } else { false }
        }
    }
}
