import SwiftUI

/// Previews for Finder settings: one miniature Finder window whose contents
/// change with the setting being shown.
struct FinderPreview: View {
    let id: String
    let option: String?

    private var isOn: Bool { option == "on" }

    private struct Item: Identifiable {
        let name: String
        var ext = ""
        var isFolder = false
        var isHidden = false
        var id: String { name + ext }
    }

    var body: some View {
        Group {
            switch id {
            case "finder.default-view": viewStyles
            case "finder.search-scope": searchScope
            case "finder.extension-warning": extensionWarning
            case "finder.library": home
            case "finder.ds-store-network": drive(title: "Shared Drive", symbol: "externaldrive.connected.to.line.below")
            case "finder.ds-store-usb": drive(title: "USB Drive", symbol: "externaldrive")
            default: documents
            }
        }
        .animation(Motion.surface, value: option)
    }

    // MARK: Documents folder (hidden files, extensions, bars, sorting)

    private var documentItems: [Item] {
        var items = [
            Item(name: "Projects", isFolder: true),
            Item(name: ".gitignore", isHidden: true),
            Item(name: "Budget", ext: "numbers"),
            Item(name: "Archive", isFolder: true),
            Item(name: ".zshrc", isHidden: true),
            Item(name: "Notes", ext: "txt"),
            Item(name: "Photo", ext: "png"),
        ]
        if !(id == "finder.hidden-files" && isOn) {
            items.removeAll(where: \.isHidden)
        }
        let byName: (Item, Item) -> Bool = {
            $0.name.trimmingPrefix(".").localizedCaseInsensitiveCompare($1.name.trimmingPrefix(".")) == .orderedAscending
        }
        if id == "finder.folders-first", isOn {
            return items.filter(\.isFolder).sorted(by: byName) + items.filter { !$0.isFolder }.sorted(by: byName)
        }
        return items.sorted(by: byName)
    }

    private var showsExtensions: Bool {
        id == "finder.extensions" ? isOn : true
    }

    private var documents: some View {
        MiniWindow(title: "Documents") {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ForEach(documentItems) { item in
                        row(item)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 2)
                Spacer(minLength: 0)

                if id == "finder.path-bar", isOn {
                    bar {
                        ForEach(Array(["Macintosh HD", "Users", "you", "Documents"].enumerated()), id: \.offset) { index, part in
                            if index > 0 {
                                Image(systemName: "chevron.right").font(.system(size: 6, weight: .bold)).foregroundStyle(.tertiary)
                            }
                            Image(systemName: index == 0 ? "internaldrive" : "folder.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(index == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.blue))
                            Text(part).mini(size: 9)
                        }
                        Spacer()
                    }
                }
                if id == "finder.status-bar", isOn {
                    bar {
                        Text("\(documentItems.count) items, 212.4 GB available")
                            .mini(size: 9)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func bar(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 4, content: content)
            .padding(.horizontal, 9)
            .frame(height: 20)
            .background(.primary.opacity(0.05))
            .overlay(alignment: .top) { Rectangle().fill(.primary.opacity(0.1)).frame(height: 0.5) }
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func row(_ item: Item, selected: Bool = false) -> some View {
        HStack(spacing: 6) {
            icon(item, size: 11)
            (Text(item.name) + Text(showsExtensions && !item.ext.isEmpty ? ".\(item.ext)" : "").foregroundStyle(id == "finder.extensions" ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary)))
                .mini()
            Spacer()
        }
        .opacity(item.isHidden ? 0.5 : 1)
        .padding(.horizontal, 6)
        .frame(height: 21)
        .background(selected ? Color.accentColor.opacity(0.25) : .clear, in: .rect(cornerRadius: 4))
    }

    private func icon(_ item: Item, size: CGFloat) -> some View {
        Image(systemName: item.isFolder ? "folder.fill" : "doc.fill")
            .font(.system(size: size))
            .foregroundStyle(item.isFolder ? AnyShapeStyle(.blue) : AnyShapeStyle(.secondary))
            .frame(width: size * 1.4)
    }

    // MARK: Default view

    private var viewStyles: some View {
        let items = [
            Item(name: "Archive", isFolder: true), Item(name: "Projects", isFolder: true),
            Item(name: "Budget", ext: "numbers"), Item(name: "Notes", ext: "txt"), Item(name: "Photo", ext: "png"),
        ]
        return MiniWindow(title: "Documents") {
            Group {
                switch option {
                case "list":
                    VStack(spacing: 0) { ForEach(items) { row($0) } }
                        .padding(.horizontal, 8)
                case "column":
                    HStack(spacing: 0) {
                        VStack(spacing: 0) {
                            ForEach(items) { row($0, selected: $0.name == "Projects") }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 5)
                        .frame(width: 130)
                        Rectangle().fill(.primary.opacity(0.1)).frame(width: 0.5)
                        VStack(spacing: 0) {
                            row(Item(name: "Website", isFolder: true))
                            row(Item(name: "Plan", ext: "pdf"), selected: true)
                            Spacer()
                        }
                        .padding(.horizontal, 5)
                        .frame(width: 120)
                        Rectangle().fill(.primary.opacity(0.1)).frame(width: 0.5)
                        Image(systemName: "doc.fill").font(.system(size: 44)).foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case "gallery":
                    VStack(spacing: 8) {
                        Image(systemName: "photo.fill").font(.system(size: 64)).foregroundStyle(.tertiary)
                            .frame(maxHeight: .infinity)
                        HStack(spacing: 8) {
                            ForEach(items) { item in
                                icon(item, size: 16)
                                    .padding(4)
                                    .background(item.name == "Photo" ? Color.accentColor.opacity(0.25) : .clear, in: .rect(cornerRadius: 4))
                            }
                        }
                        .padding(.bottom, 8)
                    }
                default:
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(items) { item in
                            VStack(spacing: 3) {
                                icon(item, size: 28)
                                Text(item.name).mini(size: 9)
                            }
                        }
                    }
                    .padding(12)
                }
            }
            .transition(.opacity)
            .id(option)
        }
    }

    // MARK: Search scope

    private var searchScope: some View {
        MiniWindow(title: "Documents") {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass").font(.system(size: 8)).foregroundStyle(.secondary)
                        Text("report").mini()
                        Spacer()
                    }
                    .padding(.horizontal, 6)
                    .frame(width: 130, height: 18)
                    .background(.primary.opacity(0.07), in: .capsule)
                }
                .padding(.horizontal, 8)

                HStack(spacing: 6) {
                    Text("Search:").mini().foregroundStyle(.secondary)
                    scopePill("This Mac", selected: option == "mac")
                    scopePill("“Documents”", selected: option == "folder")
                    if option == "previous" {
                        Label("whichever you used last", systemImage: "clock")
                            .mini(size: 9)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                    Spacer()
                }
                .padding(.horizontal, 9)
                .frame(height: 26)

                Rectangle().fill(.primary.opacity(0.1)).frame(height: 0.5)
                VStack(spacing: 0) {
                    row(Item(name: "Q3 report", ext: "pdf"))
                    row(Item(name: "Report draft", ext: "txt"))
                    if option != "folder" {
                        row(Item(name: "Old report", ext: "pdf")).transition(.opacity)
                        row(Item(name: "Expense report", ext: "numbers")).transition(.opacity)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 3)
            }
        }
    }

    private func scopePill(_ title: String, selected: Bool) -> some View {
        Text(title)
            .mini(weight: selected ? .semibold : .regular)
            .padding(.horizontal, 7)
            .frame(height: 17)
            .background(selected ? Color.accentColor.opacity(0.3) : .primary.opacity(0.07), in: .rect(cornerRadius: 4))
    }

    // MARK: Extension warning

    private var extensionWarning: some View {
        ZStack {
            MiniWindow(title: "Documents") {
                VStack(spacing: 0) {
                    row(Item(name: "Budget", ext: "numbers"))
                    row(Item(name: "Notes", ext: isOn ? "txt" : "md"), selected: true)
                    row(Item(name: "Photo", ext: "png"))
                }
                .padding(.horizontal, 8)
            }
            if isOn {
                MiniPanel(width: 210) {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 20)).foregroundStyle(.yellow)
                        Text("Change “.txt” to “.md”?").mini(size: 10.5, weight: .semibold)
                        HStack(spacing: 6) {
                            MiniButton(title: "Use .md")
                            MiniButton(title: "Keep .txt", prominent: true)
                        }
                    }
                }
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            } else {
                StageCaption(text: "Renamed right away")
            }
        }
    }

    // MARK: Library folder

    private var home: some View {
        MiniWindow(title: "you") {
            VStack(spacing: 0) {
                row(Item(name: "Desktop", isFolder: true))
                row(Item(name: "Documents", isFolder: true))
                row(Item(name: "Downloads", isFolder: true))
                if isOn {
                    row(Item(name: "Library", isFolder: true), selected: true)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
                }
                row(Item(name: "Pictures", isFolder: true))
            }
            .padding(.horizontal, 8)
        }
    }

    // MARK: .DS_Store files

    private func drive(title: String, symbol: String) -> some View {
        MiniWindow(title: title) {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    if !isOn {
                        row(Item(name: ".DS_Store", isHidden: true), selected: true)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
                    }
                    row(Item(name: "Photos", isFolder: true))
                    row(Item(name: "Report", ext: "pdf"))
                    row(Item(name: "Slides", ext: "key"))
                }
                .padding(.horizontal, 8)
                Spacer()
                bar {
                    Image(systemName: symbol).font(.system(size: 8)).foregroundStyle(.secondary)
                    Text(isOn ? "Nothing extra is left behind" : "Finder leaves a hidden layout file here")
                        .mini(size: 9)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                    Spacer()
                }
            }
            .padding(.horizontal, 0)
        }
    }
}
