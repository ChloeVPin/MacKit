import MacKitCore
import SwiftUI

struct CategoryView: View {
    let category: TweakCategory

    @Environment(AppModel.self) private var model
    @State private var filter = Filter.all

    /// Which part of a category is showing.
    private enum Filter: Hashable {
        case all
        case changed
        case section(String)
    }

    /// The filter in effect. "Changed" with nothing left under it falls back
    /// to everything.
    private var shown: Filter {
        filter == .changed && model.customizedCount(in: category) == 0 ? .all : filter
    }

    var body: some View {
        let tweaks = model.tweaks(in: category)
        let customized = model.customizedCount(in: category)
        let sections = tweaks.reduce(into: [String]()) { names, tweak in
            if names.last != tweak.section { names.append(tweak.section) }
        }

        Page {
            PageHeader(symbol: category.symbol, title: category.title, subtitle: category.blurb) {
                MoreButton(items: [
                    .init(title: "Reset \(category.title) to Defaults", isEnabled: customized > 0) {
                        model.resetToDefaults(category)
                    },
                ])
            }

            if tweaks.contains(where: model.isLocked) {
                FullDiskAccessNotice()
            }

            if sections.count > 1 || customized > 0 {
                ChipBar {
                    chip("All", .all)
                    if customized > 0 {
                        chip("Changed", .changed, count: customized)
                    }
                    if sections.count > 1 {
                        ForEach(sections, id: \.self) { section in
                            chip(section, .section(section))
                        }
                    }
                }
            }

            TweakSections(tweaks: tweaks.filter { tweak in
                switch shown {
                case .all: true
                case .changed: model.isCustomized(tweak)
                case .section(let name): tweak.section == name
                }
            })
        }
        .onChange(of: category) { self.filter = .all }
    }

    private func chip(_ title: String, _ value: Filter, count: Int? = nil) -> some View {
        Chip(title: title, count: count, isSelected: shown == value) {
            withAnimation(Motion.state) { filter = value }
        }
    }
}

struct SearchResultsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let results = model.searchResults
        let query = model.searchText.trimmingCharacters(in: .whitespaces)

        Page {
            if results.isEmpty {
                EmptyState(
                    symbol: "magnifyingglass",
                    title: "No results for “\(query)”",
                    message: "Try a broader word, like “dock” or “screenshot”."
                )
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Results")
                        .text(.title)
                    Text("\(results.count) \(results.count == 1 ? "setting matches" : "settings match") “\(query)”")
                        .text(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                TweakSections(tweaks: results, showsCategory: true)
            }
        }
    }
}
