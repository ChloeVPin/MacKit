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

    /// The filter in effect. "Customized" with nothing left under it falls
    /// back to everything.
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

            if tweaks.isEmpty {
                // Every setting here depends on hardware this Mac doesn't have.
                EmptyState(
                    symbol: category.symbol,
                    title: "Nothing to change on this Mac",
                    message: "These settings are for hardware this Mac doesn't have."
                )
            }

            if sections.count > 1 || customized > 0 {
                ChipBar {
                    chip("All", .all)
                    if customized > 0 {
                        // The same word as the count on Home: settings that
                        // differ from the default, not changes waiting for review.
                        chip("Customized", .changed, count: customized)
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
                    title: "No settings match “\(query)”",
                    message: "Try a broader word, like “dock” or “screenshot”."
                )
            } else {
                PageHeader(
                    symbol: "magnifyingglass",
                    title: "Results",
                    subtitle: "\(results.count) \(results.count == 1 ? "setting matches" : "settings match") “\(query)”"
                )
                TweakSections(tweaks: results, showsCategory: true)
            }
        }
    }
}
