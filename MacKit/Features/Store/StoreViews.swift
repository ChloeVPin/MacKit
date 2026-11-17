import MacKitCore
import SwiftUI

// MARK: Discover

/// The front of the store: popular apps, categories, and search.
struct DiscoverView: View {
    @Environment(AppModel.self) private var model

    private let columns = [GridItem(.flexible(), spacing: Space.m), GridItem(.flexible(), spacing: Space.m)]

    var body: some View {
        let store = model.store
        let query = model.searchText.trimmingCharacters(in: .whitespaces)

        Page {
            PageHeader(symbol: "sparkles", title: "Discover", subtitle: subtitle(store)) {
                if store.phase == .ready, query.isEmpty {
                    SortMenu()
                }
            }

            switch store.phase {
            case .loading:
                PageLoading(label: "Loading apps")
            case .failed(let message):
                VStack(spacing: Space.m) {
                    EmptyState(symbol: "wifi.slash", title: "Can't load apps", message: message)
                    Button("Try Again") { Task { await store.reload() } }
                        .buttonStyle(PillButtonStyle(isLarge: true))
                }
                .frame(maxWidth: .infinity)
            case .ready:
                if !query.isEmpty {
                    results(store.search(query), query: query)
                } else {
                    CategoryBar()
                    if let category = store.category {
                        shelf(category.title, store.apps(in: category))
                    } else if store.showingPopularAll {
                        shelf("Popular Right Now", Array(store.apps(in: nil).prefix(StoreModel.popularExpandedCount))) {
                            Button("Back to Featured") {
                                withAnimation(Motion.state) { store.showingPopularAll = false }
                            }
                            .buttonStyle(QuietLinkStyle())
                        }
                    } else if store.sort == .name {
                        shelf("All Apps", store.apps(in: nil))
                    } else {
                        front(store)
                    }
                }
            }
        }
        .task { await store.loadIfNeeded() }
    }

    private func subtitle(_ store: StoreModel) -> String {
        store.apps.isEmpty
            ? "Apps for your Mac, downloaded straight from the people who make them."
            : "\(store.apps.count.formatted()) apps, downloaded straight from the people who make them."
    }

    /// The front page: what's popular overall, then a taste of each category.
    @ViewBuilder private func front(_ store: StoreModel) -> some View {
        shelf("Popular Right Now", Array(store.apps.prefix(StoreModel.popularCount))) {
            if store.apps.count > StoreModel.popularCount {
                Button("See All") {
                    withAnimation(Motion.state) { store.showingPopularAll = true }
                }
                .buttonStyle(QuietLinkStyle())
            }
        }
        ForEach(StoreCategory.allCases) { category in
            let apps = store.shelfApps(for: category)
            if !apps.isEmpty {
                shelf(category.title, apps) {
                    Button("See All") {
                        withAnimation(Motion.state) { store.category = category }
                    }
                    .buttonStyle(QuietLinkStyle())
                }
            }
        }
    }

    private func shelf(_ title: String, _ apps: [StoreApp]) -> some View {
        shelf(title, apps) { EmptyView() }
    }

    private func shelf(_ title: String, _ apps: [StoreApp], @ViewBuilder trailing: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .text(.heading)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                trailing()
            }
            .padding(.horizontal, Space.xs)

            LazyVGrid(columns: columns, spacing: Space.m) {
                ForEach(apps) { app in
                    AppCard(app: app)
                }
            }
        }
    }

    @ViewBuilder private func results(_ apps: [StoreApp], query: String) -> some View {
        if apps.isEmpty {
            EmptyState(
                symbol: "magnifyingglass",
                title: "No apps match “\(query)”",
                message: "Try the app's name, or a word for what it does."
            )
        } else {
            shelf("\(apps.count.formatted()) \(apps.count == 1 ? "app" : "apps") for “\(query)”", apps)
        }
    }
}

/// The row of categories under the header.
private struct CategoryBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ChipBar {
            chip("All", nil)
            ForEach(StoreCategory.allCases) { category in
                chip(category.title, category)
            }
        }
    }

    private func chip(_ title: String, _ category: StoreCategory?) -> some View {
        let isSelected = model.store.category == category && (category != nil || !model.store.showingPopularAll)
        return Chip(title: title, isSelected: isSelected) {
            withAnimation(Motion.state) {
                model.store.category = category
                model.store.showingPopularAll = false
            }
        }
    }
}

private struct SortMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var store = model.store
        Picker("Sort", selection: $store.sort) {
            ForEach(StoreModel.Sort.allCases) { sort in
                Text(sort.rawValue).tag(sort)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
        .help("Sort apps")
    }
}

// MARK: Installed

struct InstalledAppsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let store = model.store
        let apps = store.installedApps
        let updates = apps.filter(store.hasUpdate)

        Page {
            PageHeader(
                symbol: "arrow.down.circle.fill", title: "Installed",
                subtitle: "Apps on this Mac that are in the store, however they got here."
            ) {
                if updates.count > 1 {
                    Button("Update All") { updates.forEach(store.install) }
                        .buttonStyle(PillButtonStyle(isTinted: true, isLarge: true))
                }
            }

            if store.phase == .loading {
                PageLoading(label: "Loading apps")
            } else if apps.isEmpty {
                EmptyState(
                    symbol: "square.dashed",
                    title: "Nothing from the store yet",
                    message: "Apps you install from Discover show up here, along with any you already have."
                )
            } else {
                if !updates.isEmpty {
                    list("Updates Available", updates)
                }
                let current = apps.filter { !store.hasUpdate($0) }
                if !current.isEmpty {
                    list(updates.isEmpty ? "On This Mac" : "Up to Date", current)
                }
            }
        }
        .task {
            await store.loadIfNeeded()
            store.refreshInstalled()
        }
    }

    private func list(_ title: String, _ apps: [StoreApp]) -> some View {
        CardSection(title: title) {
            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                if index > 0 { RowDivider() }
                AppRow(app: app)
            }
        }
    }
}

// MARK: One app

/// An app's own page.
struct AppDetailView: View {
    let app: StoreApp

    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        let store = model.store

        Page {
            HStack(alignment: .center, spacing: Space.l + 2) {
                AppIcon(app: app, size: 96)
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(app.name)
                        .text(.title)
                        .lineLimit(2)
                    Text(app.summary)
                        .text(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Space.s) {
                        GetButton(app: app, isLarge: true)
                        if let homepage = app.homepage {
                            Button("Website") { openURL(homepage) }
                                .buttonStyle(PillButtonStyle(isLarge: true))
                                .help(homepage.absoluteString)
                        }
                    }
                    .padding(.top, Space.s)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, Space.xs)

            if case .failed(let message) = store.activity[app.id] {
                Label {
                    Text(message)
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

            CardSection(title: "Information") {
                fact("Version", app.displayVersion)
                if let installed = store.installed[app.id] {
                    RowDivider()
                    fact("On this Mac", installed.isEmpty ? "Installed" : installed)
                }
                RowDivider()
                fact("Downloads from", app.downloadHost)
                RowDivider()
                fact("Checked against", app.checksum == nil ? "Apple's developer check" : "The maker's checksum, and Apple's developer check")
                RowDivider()
                fact("Updates", app.updatesItself ? "The app updates itself" : "Update from here")
                if let minimum = app.minimumSystem {
                    RowDivider()
                    fact("Requires", "macOS \(minimum) or later")
                }
                if app.installs > 0 {
                    RowDivider()
                    fact("Popularity", "\(app.installs.formatted()) installs in the last 30 days")
                }
                if let category = app.category {
                    RowDivider()
                    fact("Category", category.title)
                }
            }

            if store.isInstalled(app) {
                HStack(spacing: Space.s) {
                    Button("Show in Finder") { store.showInFinder(app) }
                        .buttonStyle(PillButtonStyle(isLarge: true))
                    Button("Move to Trash") { store.uninstall(app) }
                        .buttonStyle(PillButtonStyle(isLarge: true))
                }
                .padding(.leading, Space.xs)
            }

            Text("App details come from Homebrew Cask, a public list kept by volunteers. MacKit downloads the app from the address above, the same one its maker publishes.")
                .text(.detail)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.xs)
        }
        .navigationTitle(app.name)
        .onKeyPress(.escape) {
            store.openAppID = nil
            return .handled
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    store.openAppID = nil
                } label: {
                    Label(model.destination.title, systemImage: "chevron.left")
                }
                .help("Back to \(model.destination.title)")
                .keyboardShortcut("[", modifiers: .command)
            }
        }
    }

    private func fact(_ name: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            Text(name)
                .text(.label)
            Spacer(minLength: Space.l)
            Text(value)
                .text(.label)
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
}

// MARK: Pieces

/// An app in a grid: icon, name, a line about it, and the button.
struct AppCard: View {
    let app: StoreApp

    @Environment(AppModel.self) private var model
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        let failure = failureMessage
        HStack(spacing: Space.m) {
            Button {
                model.store.openAppID = app.id
            } label: {
                HStack(spacing: Space.m) {
                    AppIcon(app: app, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text(failure ?? app.summary)
                            .text(.detail)
                            .foregroundStyle(failure != nil ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, minHeight: 28, alignment: .topLeading)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows details about \(app.name).")

            GetButton(app: app)
        }
        .padding(Layout.cardInset)
        .background(isHovered ? AnyShapeStyle(.rowHover) : AnyShapeStyle(.card), in: shape)
        .overlay { shape.strokeBorder(.primary.opacity(contrast == .increased ? 0.28 : 0.06), lineWidth: 1) }
        .contentShape(shape)
        .onHover { isHovered = $0 }
        .onTapGesture { model.store.openAppID = app.id }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Show Details") { model.store.openAppID = app.id }
    }

    private var failureMessage: String? {
        if case .failed(let message) = model.store.activity[app.id] { message } else { nil }
    }
}

/// An app in a list, for the Installed page.
struct AppRow: View {
    let app: StoreApp

    @Environment(AppModel.self) private var model
    @State private var isHovered = false

    var body: some View {
        let store = model.store
        let failure = failureMessage(store)
        HStack(spacing: Space.m) {
            Button {
                store.openAppID = app.id
            } label: {
                HStack(spacing: Space.m) {
                    AppIcon(app: app, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .text(.label)
                            .lineLimit(1)
                        Text(failure ?? versionLine(store))
                            .text(.detail)
                            .foregroundStyle(failure != nil ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows details about \(app.name).")

            GetButton(app: app)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .contentShape(.rect)
                .onTapGesture { store.openAppID = app.id }
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Layout.cardInset)
        .padding(.vertical, Space.s + 2)
        .background(isHovered ? Color.rowHover : Color.clear)
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .onTapGesture { store.openAppID = app.id }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Show Details") { store.openAppID = app.id }
    }

    private func failureMessage(_ store: StoreModel) -> String? {
        if case .failed(let message) = store.activity[app.id] { message } else { nil }
    }

    private func versionLine(_ store: StoreModel) -> String {
        let installed = store.installed[app.id] ?? ""
        if store.hasUpdate(app) { return "\(installed) installed · \(app.displayVersion) available" }
        return installed.isEmpty ? app.summary : "Version \(installed)"
    }
}

/// An app's icon.
///
/// Every app shows something that reads as an icon. A finished Mac icon is
/// shown as it is. A square picture gets an icon's rounded corners. A small
/// favicon sits on a white tile. And an app with no picture anywhere gets a
/// tile in its own color with its initial, the same every time.
struct AppIcon: View {
    let app: StoreApp
    let size: CGFloat

    @Environment(AppModel.self) private var model
    @State private var resolved: StoreModel.CachedIcon = .unknown

    var body: some View {
        // Mac icons leave a margin inside their square. Tiles drawn here
        // match it, so every icon in a row looks the same size.
        let tile = size * 0.84
        let shape = RoundedRectangle(cornerRadius: tile * 0.225, style: .continuous)
        let revision = model.store.iconRevisions[app.id, default: 0]
        let state: StoreModel.CachedIcon = switch resolved {
        case .unknown: model.store.cachedIcon(for: app)
        case .found, .missing: resolved
        }
        let icon: StoreIcon? = if case .found(let found) = state { found } else { nil }
        let isMissing: Bool = if case .missing = state { true } else { false }

        Group {
            switch icon?.shape {
            case .finished?:
                picture(icon!.image)
            case .square?:
                picture(icon!.image)
                    .frame(width: tile, height: tile)
                    .clipShape(shape)
                    .overlay { shape.strokeBorder(.black.opacity(0.1), lineWidth: 0.5) }
            case .small?:
                picture(icon!.image)
                    .frame(width: tile * 0.52, height: tile * 0.52)
                    .frame(width: tile, height: tile)
                    .background(.white, in: shape)
                    .overlay { shape.strokeBorder(.black.opacity(0.12), lineWidth: 0.5) }
            case nil where !isMissing:
                // Still looking. Nothing shows until the answer is in, so a
                // stand-in never flashes before the real icon.
                Color.clear
            case nil:
                Text(app.name.prefix(1).uppercased())
                    .font(.system(size: tile * 0.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: tile, height: tile)
                    .background(Self.color(for: app.id).gradient, in: shape)
                    .overlay { shape.strokeBorder(.white.opacity(0.18), lineWidth: 0.5) }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(icon?.shape == .finished ? 0 : 0.12), radius: size * 0.03, y: size * 0.015)
        .animation(Motion.fade, value: icon != nil)
        .animation(Motion.fade, value: isMissing)
        .task(id: "\(app.id)#\(revision)") {
            resolved = model.store.cachedIcon(for: app)
            if case .unknown = resolved {
                let loaded = await model.store.loadIcon(for: app)
                guard !Task.isCancelled else { return }
                resolved = loaded.map(StoreModel.CachedIcon.found) ?? .missing
            }
        }
        .accessibilityHidden(true)
    }

    private func picture(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .transition(.opacity)
    }

    /// A color that belongs to the app: the same name always gives the same
    /// one, on every Mac.
    private static func color(for id: String) -> Color {
        // Swift's own hashing changes between launches, so add up the
        // letters instead.
        let sum = id.unicodeScalars.reduce(UInt32(7)) { ($0 &* 31) &+ $1.value }
        return Color(hue: Double(sum % 360) / 360, saturation: 0.55, brightness: 0.72)
    }
}

/// The store's button shape: a capsule, tinted for the main action.
struct PillButtonStyle: ButtonStyle {
    var isTinted = false
    var isLarge = false
    /// A set width, for buttons that must not change size as their label
    /// changes. Otherwise the pill is as wide as its label needs.
    var width: CGFloat?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: isLarge ? 13 : 12, weight: .semibold))
            .foregroundStyle(isTinted ? Color.accentColor : .primary)
            .lineLimit(1)
            .padding(.horizontal, width == nil ? (isLarge ? 18 : 14) : 0)
            .frame(minWidth: width ?? (isLarge ? 78 : 58))
            .frame(height: isLarge ? 30 : 24)
            .background(isTinted ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.08), in: .capsule)
            .contentShape(.capsule)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// The button that gets, updates, or opens an app.
///
/// It is the same size in every state, so nothing around it moves. While an
/// app downloads, the pill fills from the left and shows the percentage.
/// While the app is checked and copied into place, it shows a spinner.
struct GetButton: View {
    let app: StoreApp
    var isLarge = false

    @Environment(AppModel.self) private var model

    /// Wide enough for the longest label, "Update".
    private var width: CGFloat { isLarge ? 86 : 72 }
    private var height: CGFloat { isLarge ? 30 : 24 }

    var body: some View {
        let store = model.store

        Group {
            switch store.activity[app.id] {
            case .downloading(let fraction):
                Button {
                    store.cancel(app)
                } label: {
                    ProgressPill(fraction: fraction, width: width, height: height, isLarge: isLarge)
                }
                .buttonStyle(.plain)
                .help("Click to stop")
                .accessibilityLabel("Downloading \(app.name)")
                .accessibilityValue(fraction.map { "\(Int($0 * 100)) percent" } ?? "")
                .accessibilityHint("Stops the download")
            case .verifying, .installing:
                ProgressView()
                    .controlSize(.small)
                    .frame(width: width, height: height)
                    .background(Color.accentColor.opacity(0.14), in: .capsule)
                    .accessibilityLabel("Installing \(app.name)")
            case .failed(let message):
                Button("Retry") {
                    store.dismissFailure(app)
                    store.install(app)
                }
                .buttonStyle(PillButtonStyle(isTinted: true, isLarge: isLarge, width: width))
                .help(message)
                .accessibilityLabel("Retry installing \(app.name)")
                .accessibilityHint(message)
            case nil:
                if store.hasUpdate(app) {
                    Button("Update") { store.install(app) }
                        .buttonStyle(PillButtonStyle(isTinted: true, isLarge: isLarge, width: width))
                        .accessibilityLabel("Update \(app.name)")
                } else if store.isInstalled(app) {
                    Button("Open") { store.open(app) }
                        .buttonStyle(PillButtonStyle(isLarge: isLarge, width: width))
                        .accessibilityLabel("Open \(app.name)")
                } else {
                    Button("Get") { store.install(app) }
                        .buttonStyle(PillButtonStyle(isTinted: true, isLarge: isLarge, width: width))
                        .accessibilityLabel("Get \(app.name)")
                }
            }
        }
        .frame(width: width, height: height)
    }
}

/// A pill that fills as a download arrives, with the percentage on top.
private struct ProgressPill: View {
    /// How much has arrived. `nil` when the server doesn't say how big the
    /// file is.
    let fraction: Double?
    let width: CGFloat
    let height: CGFloat
    let isLarge: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Capsule().fill(Color.accentColor.opacity(0.14))
            // A soft fill, so the percentage reads the same on both sides of
            // its edge and never has to change color.
            Capsule()
                .fill(Color.accentColor.opacity(0.3))
                .mask(alignment: .leading) {
                    Rectangle().frame(width: width * min(max(fraction ?? 0, 0), 1))
                }
                .animation(reduceMotion ? nil : .linear(duration: 0.15), value: fraction)
            if let fraction {
                Text("\(Int(fraction * 100))%")
                    .font(.system(size: isLarge ? 13 : 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
                    .contentTransition(.identity)
                    .animation(nil, value: fraction)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(width: width, height: height)
        .clipShape(.capsule)
        .contentShape(.capsule)
    }
}
