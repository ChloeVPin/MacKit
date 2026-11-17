import MacKitCore
import SwiftUI

@main
struct MacKitApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var model = SampleData.modelForLaunch() ?? AppModel.live()

    var body: some Scene {
        Window("MacKit", id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: 820, minHeight: 540)
                .task {
                    // "-start discover" opens straight to the store.
                    if UserDefaults.standard.string(forKey: "start") == "discover" { model.go(to: .discover) }
                    if let id = UserDefaults.standard.string(forKey: "startApp") {
                        model.go(to: .discover)
                        model.store.openAppID = id
                    }
                    #if DEBUG
                    // "-startGet <id>" starts a real install, for testing the
                    // whole path without clicking. Debug builds only.
                    if let id = UserDefaults.standard.string(forKey: "startGet") {
                        model.go(to: .discover)
                        await model.store.loadIfNeeded()
                        if let app = model.store.app(id) {
                            model.store.openAppID = id
                            model.store.install(app)
                        }
                    }
                    #endif
                    await model.load()
                }
        }
        .defaultSize(width: 1120, height: 720)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .sidebar) {
                Button(model.destination.isStore ? "Reload Apps" : "Reload Settings") {
                    Task {
                        if model.destination.isStore {
                            await model.store.reload()
                            model.store.refreshInstalled()
                        } else {
                            await model.refresh()
                        }
                    }
                }
                .keyboardShortcut("r")
                Divider()
            }
            CommandMenu("Changes") {
                Button("Review Changes…") {
                    model.beginReview()
                }
                .keyboardShortcut(.return)
                .disabled(model.pending.isEmpty)

                Button("Discard Changes") {
                    model.discardPending()
                }
                .keyboardShortcut(.delete)
                .disabled(model.pending.isEmpty)
            }
            CommandMenu("Go") {
                Button("Search Settings") { model.searchFocusRequests += 1 }
                    .keyboardShortcut("f")
                Divider()
                Button("Home") { model.go(to: .home) }
                    .keyboardShortcut("0")
                Button("Discover Apps") { model.go(to: .discover) }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                Button("Installed Apps") { model.go(to: .installed) }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                ForEach(TweakCategory.Group.allCases) { group in
                    Divider()
                    ForEach(group.categories) { category in
                        // The first nine get Command-1 through Command-9.
                        let index = TweakCategory.allCases.firstIndex(of: category) ?? 9
                        if index < 9 {
                            Button(category.title) { model.go(to: .category(category)) }
                                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))))
                        } else {
                            Button(category.title) { model.go(to: .category(category)) }
                        }
                    }
                }
                Divider()
                Button("History") { model.go(to: .history) }
                    .keyboardShortcut("y")
            }
        }
    }
}

/// MacKit is a single-window utility, so closing the window quits it.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
