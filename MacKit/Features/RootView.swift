import MacKitCore
import SwiftUI

/// The sidebar search field is AppKit's, which `focusEffectDisabled` doesn't
/// reach, so its ring is turned off on the field itself.
@MainActor private func hideSearchFocusRing() {
    func visit(_ view: NSView) {
        if let field = view as? NSSearchField { field.focusRingType = .none }
        view.subviews.forEach(visit)
    }
    for window in NSApp.windows {
        if let frame = window.contentView?.superview { visit(frame) }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 236, ideal: 240, max: 290)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ChangesBar()
                }
                // Pages fade softly under the toolbar, so the hard separator
                // line macOS adds above a scroll view would only add noise.
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .searchable(text: $model.searchText, placement: .sidebar, prompt: model.destination.isStore ? "Search Apps" : "Search Settings")
        .searchFocused($isSearchFocused)
        .onChange(of: model.searchFocusRequests) { isSearchFocused = true }
        // Without this, the search field takes focus at launch and the window
        // opens with a focus ring nobody asked for. Letting go of the search
        // field hands focus to the next text field on the page, so clear
        // that too.
        .task {
            try? await Task.sleep(for: .milliseconds(50))
            isSearchFocused = false
            try? await Task.sleep(for: .milliseconds(50))
            NSApp.keyWindow?.makeFirstResponder(nil)
            hideSearchFocusRing()
        }
        // No colored outline around whatever was clicked last. Selection and
        // the text cursor already show where you are.
        .focusEffectDisabled()
        .navigationTitle(model.destination.title)
        .toolbar(removing: .title)
        .sheet(item: $model.review) { session in
            ReviewSheet(session: session)
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    @ViewBuilder private var detail: some View {
        let isSearching = !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty
        if model.destination.isStore {
            // In the store, the search field looks for apps, not settings.
            if let id = model.store.openAppID, let app = model.store.app(id), !isSearching {
                AppDetailView(app: app).id(id)
            } else if model.destination == .installed, !isSearching {
                InstalledAppsView()
            } else {
                DiscoverView()
            }
        } else if isSearching {
            SearchResultsView()
        } else if let id = model.openTweakID, let tweak = model.tweak(id) {
            TweakDetailView(tweak: tweak).id(id)
        } else {
            switch model.destination {
            case .home: HomeView()
            case .discover, .installed: EmptyView()
            case .category(let category): CategoryView(category: category).id(category)
            case .history: HistoryView()
            }
        }
    }
}
