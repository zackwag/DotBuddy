import SwiftUI

struct LibraryView: View {
    @ObservedObject var aliasViewModel: AliasViewModel
    @ObservedObject var envViewModel: EnvViewModel
    var onBack: () -> Void

    @State private var searchText = ""
    @State private var selectedTab: LibraryTab = .aliases
    @State private var addedItems: Set<String> = []

    enum LibraryTab {
        case aliases, environment
    }

    var body: some View {
        VStack(spacing: 0) {
            picker
            Divider()
            if filteredCategories.isEmpty {
                emptyState
            } else {
                categoryList
            }
            Divider()
            statusBar
        }
        .toolbar { toolbarContent }
        .navigationTitle("DotBuddy — Library")
        .navigationSubtitle(selectedTab == .aliases ? "Alias Suggestions" : "Environment Variable Suggestions")
        .searchable(text: $searchText, prompt: "Search library")
    }

    private var picker: some View {
        Picker("", selection: $selectedTab) {
            Text("Aliases").tag(LibraryTab.aliases)
            Text("Environment").tag(LibraryTab.environment)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var filteredCategories: [LibraryCategory] {
        let categories = selectedTab == .aliases
            ? LibraryData.aliasCategories
            : LibraryData.envCategories

        if searchText.isEmpty {
            return categories
        }

        let query = searchText.lowercased()
        return categories.compactMap { category in
            let filtered = category.items.filter {
                $0.name.lowercased().contains(query) ||
                $0.value.lowercased().contains(query) ||
                $0.description.lowercased().contains(query)
            }
            if filtered.isEmpty { return nil }
            return LibraryCategory(name: category.name, icon: category.icon, items: filtered)
        }
    }

    private var categoryList: some View {
        List {
            ForEach(filteredCategories) { category in
                Section {
                    ForEach(category.items) { item in
                        LibraryItemRow(
                            item: item,
                            isAdded: isAlreadyAdded(item),
                            onAdd: { addItem(item) }
                        )
                    }
                } header: {
                    Label(category.name, systemImage: category.icon)
                }
            }
        }
        .alternatingRowBackgrounds()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No matching items")
                .font(.title2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var statusBar: some View {
        HStack {
            Image(systemName: "book.closed")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text("\(currentItemCount) items available")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            if !addedItems.isEmpty {
                Text("\(addedItems.count) added this session")
                    .font(.callout)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: onBack) {
                Label("Back", systemImage: "chevron.left")
            }
            .help("Back to home")
        }
    }

    private var currentItemCount: Int {
        let categories = selectedTab == .aliases
            ? LibraryData.aliasCategories
            : LibraryData.envCategories
        return categories.reduce(0) { $0 + $1.items.count }
    }

    private func isAlreadyAdded(_ item: LibraryItem) -> Bool {
        if addedItems.contains(item.name) { return true }

        switch item.type {
        case .alias:
            return aliasViewModel.workingAliases.contains { $0.name == item.name }
        case .environment:
            return envViewModel.workingVariables.contains { $0.name == item.name }
        }
    }

    private func addItem(_ item: LibraryItem) {
        switch item.type {
        case .alias:
            let success = aliasViewModel.addAlias(
                name: item.name,
                command: item.value,
                group: item.category
            )
            if success { addedItems.insert(item.name) }
        case .environment:
            let success = envViewModel.addVariable(
                name: item.name,
                value: item.value,
                group: item.category
            )
            if success { addedItems.insert(item.name) }
        }
    }
}

struct LibraryItemRow: View {
    let item: LibraryItem
    let isAdded: Bool
    let onAdd: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(.body, design: .monospaced).bold())
                    Text(item.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(item.value)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .help("Already added")
            } else {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.borderless)
                .opacity(isHovered ? 1 : 0.6)
                .help("Add to your configuration")
            }
        }
        .padding(.vertical, 2)
        .onHover { isHovered = $0 }
    }
}
