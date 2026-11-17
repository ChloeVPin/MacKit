import Foundation

/// A setting that takes a value the user enters, not only a pick from a
/// list: a number on a slider, or a line of text.
public enum ValueInput: Hashable, Sendable {
    case number(NumberInput)
    case text(TextInput)
}

public struct NumberInput: Hashable, Sendable {
    public let range: ClosedRange<Double>
    /// The smallest change the slider makes.
    public let step: Double
    /// Shown after the number, including any space: " px", "%", "×".
    public let unit: String
    /// What the stored value is multiplied by for display. 100 shows a
    /// stored 0.5 as 50.
    public let displayScale: Double
    /// Whether the value is stored as a whole number.
    public let isInteger: Bool

    public init(_ range: ClosedRange<Double>, step: Double, unit: String = "", displayScale: Double = 1, isInteger: Bool = false) {
        precondition(step > 0, "A slider needs a positive step")
        self.range = range
        self.step = step
        self.unit = unit
        self.displayScale = displayScale
        self.isInteger = isInteger
    }

    /// The nearest value the slider can rest on.
    public func snapped(_ value: Double) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let steps = ((clamped - range.lowerBound) / step).rounded()
        // Rounding again clears the tiny errors that come from adding steps.
        let snapped = range.lowerBound + steps * step
        return min((snapped * 1_000_000).rounded() / 1_000_000, range.upperBound)
    }

    public func label(for value: Double) -> String {
        let shown = value * displayScale
        let digits = shown == shown.rounded() ? 0 : (shown * 10 == (shown * 10).rounded() ? 1 : 2)
        return shown.formatted(.number.precision(.fractionLength(digits)).grouping(.never)) + unit
    }
}

public struct TextInput: Hashable, Sendable {
    /// Shown in the empty field.
    public let placeholder: String
    public let maxLength: Int
    /// Characters the setting can't hold.
    public let forbidden: String
    /// The label used for an empty value, such as "None".
    public let emptyLabel: String

    public init(placeholder: String, maxLength: Int, forbidden: String = "", emptyLabel: String = "None") {
        self.placeholder = placeholder
        self.maxLength = maxLength
        self.forbidden = forbidden
        self.emptyLabel = emptyLabel
    }

    /// The text with anything the setting can't hold removed.
    public func cleaned(_ text: String) -> String {
        let blocked = Set(forbidden)
        let kept = text.filter { !$0.isNewline && !blocked.contains($0) }
        return String(kept.prefix(maxLength))
    }
}

extension Tweak {
    // An entered value travels through the app the same way a listed option
    // does: as an option identifier. Identifiers for entered values start
    // with "=", which no listed option uses, followed by the value.
    private static let entryPrefix = "="

    /// The identifier that stands for an entered value.
    public func entryID(for value: PreferenceValue) -> TweakOption.ID {
        Self.entryPrefix + value.displayText
    }

    /// The value an identifier stands for, if it is an entered value.
    public func entry(_ id: TweakOption.ID) -> PreferenceValue? {
        guard let input, id.hasPrefix(Self.entryPrefix) else { return nil }
        let text = String(id.dropFirst(Self.entryPrefix.count))
        switch input {
        case .number(let number):
            guard let value = Double(text) else { return nil }
            return number.isInteger ? .int(Int(value.rounded())) : .double(value)
        case .text:
            return .string(text)
        }
    }

    /// The value a listed option stores, for settings kept in one key.
    public func storedValue(of id: TweakOption.ID) -> PreferenceValue? {
        guard case .preferences(let bindings) = mechanism, bindings.count == 1 else { return nil }
        return bindings[0].values[id]
    }

    /// The identifier for `value`: a listed option if one stores exactly
    /// that, otherwise an entered value.
    public func optionID(for value: PreferenceValue) -> TweakOption.ID {
        options.first { storedValue(of: $0.id)?.matches(value) == true }?.id ?? entryID(for: value)
    }

    /// How an option or entered value reads in the interface.
    public func label(for id: TweakOption.ID) -> String {
        if let option = option(id) { return option.label }
        guard let value = entry(id) else { return id }
        switch (input, value) {
        case (.number(let number), .int(let stored)): return number.label(for: Double(stored))
        case (.number(let number), .double(let stored)): return number.label(for: stored)
        default: return value.displayText
        }
    }
}

extension Tweak {
    /// Whether changing the setting can be written at once, without a
    /// review first.
    ///
    /// Most settings are small, personal, and easy to flip back, and a
    /// review step only gets in the way. A setting waits for review when
    /// getting it wrong costs something:
    /// - it needs an administrator password,
    /// - it carries a warning,
    /// - it restarts Finder, which cancels any file copy in progress, or
    /// - it is typed, so there is no clear moment when the text is finished.
    public var appliesInstantly: Bool {
        if requiresAdministrator || caution != nil { return false }
        if effect == .restarts(.finder) { return false }
        if case .text = input { return false }
        return true
    }
}
