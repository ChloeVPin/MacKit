import MacKitCore
import SwiftUI

/// One setting on its own page: the control, and the facts about it.
struct TweakDetailView: View {
    let tweak: Tweak

    @Environment(AppModel.self) private var model

    var body: some View {
        let selected = model.selectedOption(for: tweak)

        Page {
            Card {
                TweakRow(tweak: tweak, style: .detail)
            }

            if model.isLocked(tweak) {
                FullDiskAccessNotice()
                    .padding(.top, -Space.m)
            }

            if let caution = tweak.caution {
                Label {
                    Text(caution)
                        .text(.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.yellow)
                }
                .padding(.horizontal, Space.xs)
                .padding(.top, -Space.m)
            }

            CardSection(title: "About") {
                if let stock = tweak.stockOption, tweak.hasDefault {
                    fact("Default", stock.label)
                    RowDivider()
                }
                if case .custom(let raw) = model.state(of: tweak) {
                    fact("On this Mac", "A custom value (\(raw))")
                    RowDivider()
                }
                fact("Changes are", tweak.appliesInstantly ? "Applied as you make them" : "Applied after you review them")
                RowDivider()
                fact("Takes effect", effectText)
                if tweak.requiresAdministrator {
                    RowDivider()
                    fact("Requires", "An administrator password")
                }
                RowDivider()
                fact("Stored in", storage, isCode: true)
            }

            if tweak.hasDefault, selected != tweak.stockOptionID {
                Button("Reset to Default") {
                    model.select(tweak.stockOptionID, for: tweak)
                }
                .padding(.leading, Space.xs)
            }
        }
        .navigationTitle(tweak.title)
        .onKeyPress(.escape) {
            if case .text = tweak.input { return .ignored }
            model.openTweakID = nil
            return .handled
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    model.openTweakID = nil
                } label: {
                    Label(tweak.category.title, systemImage: "chevron.left")
                }
                .help("Back to \(tweak.category.title)")
                .keyboardShortcut("[", modifiers: .command)
            }
        }
    }

    private func fact(_ name: String, _ value: String, isCode: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            Text(name)
                .text(.label)
            Spacer(minLength: Space.l)
            Text(value)
                .text(isCode ? .code : .label)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Layout.cardInset)
        .padding(.vertical, Space.s + 2)
        .frame(minHeight: 38)
        .accessibilityElement(children: .combine)
    }

    private var effectText: String {
        switch tweak.effect {
        case .immediate: "Right away"
        case .restarts(let target): "After \(target.displayName) restarts, which MacKit does for you"
        case .appRelaunch: "In each app, the next time it opens"
        case .logout: "After you log out and back in"
        case .nextStartup: "The next time this Mac starts up"
        case .restart: "After you restart this Mac"
        }
    }

    /// Where the setting is stored, for people who want to find it themselves.
    private var storage: String {
        switch tweak.mechanism {
        case .preferences(let bindings):
            bindings.map {
                let keyPath = ($0.path + [$0.key]).joined(separator: ".")
                return "\($0.domain.isCurrentHost ? "-currentHost " : "")\($0.domain.commandLineName) \(keyPath)"
            }.joined(separator: "\n")
        case .libraryVisibility:
            "~/Library hidden flag"
        case .privileged(let setting):
            setting.storage
        }
    }
}

/// Explains why some settings can't be changed yet, and where to fix it.
struct FullDiskAccessNotice: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Card {
            HStack(alignment: .center, spacing: Space.m) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Needs Full Disk Access")
                        .text(.label)
                    Text("macOS keeps some apps' settings private. Allow MacKit in Privacy & Security, then reopen it.")
                        .text(.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button("Open Settings") { model.openFullDiskAccessSettings() }
            }
            .padding(.horizontal, Layout.cardInset)
            .padding(.vertical, Space.s + 2)
        }
    }
}
