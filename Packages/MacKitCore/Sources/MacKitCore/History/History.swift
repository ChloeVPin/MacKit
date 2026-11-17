import Foundation

/// One batch of changes the user applied together.
public struct HistoryRecord: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let date: Date
    public var entries: [HistoryEntry]

    public init(id: UUID = UUID(), date: Date, entries: [HistoryEntry]) {
        self.id = id
        self.date = date
        self.entries = entries
    }

    private struct LossyEntry: Decodable {
        let entry: HistoryEntry?
        init(from decoder: any Decoder) throws {
            entry = try? HistoryEntry(from: decoder)
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        let decoded = try container.decode([LossyEntry].self, forKey: .entries)
        entries = decoded.compactMap(\.entry)
    }

    public var isFullyReverted: Bool { entries.allSatisfy { $0.revertedAt != nil } }
}

/// One applied change, with everything needed to describe and undo it even
/// if the catalog changes in a later version.
public struct HistoryEntry: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let tweakID: Tweak.ID
    public let title: String
    public let category: TweakCategory
    /// The section within `category`, such as "Safari" or "On Battery".
    /// Optional so history files written by earlier builds still decode.
    public let section: String?
    /// The value before the change, as shown to the user.
    public let from: String
    /// The value after the change, as shown to the user.
    public let to: String
    public let snapshot: Snapshot
    public var revertedAt: Date?

    public init(
        id: UUID = UUID(), tweakID: Tweak.ID, title: String, category: TweakCategory,
        section: String? = nil, from: String, to: String, snapshot: Snapshot, revertedAt: Date? = nil
    ) {
        self.id = id
        self.tweakID = tweakID
        self.title = title
        self.category = category
        self.section = section
        self.from = from
        self.to = to
        self.snapshot = snapshot
        self.revertedAt = revertedAt
    }

    /// Whether the snapshot holds enough to put the setting back.
    public var canRevert: Bool {
        if revertedAt != nil { return false }
        if case .privileged(nil) = snapshot { return false }
        return true
    }
}

/// Persists history as a JSON file.
public struct HistoryStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// The store in the user's Application Support folder.
    public static func standard() -> HistoryStore {
        let folder = URL.applicationSupportDirectory.appending(path: "MacKit", directoryHint: .isDirectory)
        return HistoryStore(fileURL: folder.appending(path: "history.json"))
    }

    public func load() throws -> [HistoryRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([HistoryRecord].self, from: Data(contentsOf: fileURL))
            .filter { !$0.entries.isEmpty }
    }

    public func save(_ records: [HistoryRecord]) throws {
        let files = FileManager.default
        let folder = fileURL.deletingLastPathComponent()
        try files.createDirectory(at: folder, withIntermediateDirectories: true)
        // Never overwrite an unreadable history file without keeping a copy.
        if files.fileExists(atPath: fileURL.path(percentEncoded: false)), (try? load()) == nil {
            let stamp = Int(Date.now.timeIntervalSince1970)
            let backup = folder.appending(path: "history-unreadable-\(stamp).json")
            if !files.fileExists(atPath: backup.path(percentEncoded: false)) {
                try? files.copyItem(at: fileURL, to: backup)
            }
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(records).write(to: fileURL, options: .atomic)
    }
}
