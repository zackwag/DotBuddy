import SwiftUI

struct LibraryView: View {
    @ObservedObject var aliasViewModel: AliasViewModel
    @ObservedObject var envViewModel: EnvViewModel
    @ObservedObject var libraryStore: LibraryStore
    var onBack: () -> Void

    @State private var searchText = ""
    @State private var selectedTab: LibraryTab = .aliases
    @State private var addedItems: Set<String> = []
    @State private var selectionMode = false
    @State private var selectedItems: Set<UUID> = []
    @State private var showGroupPicker = false
    @State private var newGroupText = ""

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
            if selectionMode && !selectedItems.isEmpty {
                bulkAddBar
            } else {
                statusBar
            }
        }
        .toolbar { toolbarContent }
        .navigationTitle("DotBuddy — Library")
        .navigationSubtitle(selectedTab == .aliases ? "Alias Suggestions" : "Environment Variable Suggestions")
        .searchable(text: $searchText, prompt: "Search library")
        .onChange(of: selectedTab) { _, _ in
            selectedItems.removeAll()
        }
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
            ? libraryStore.aliasCategories
            : libraryStore.envCategories

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
                        if selectionMode {
                            LibraryItemRow(
                                item: item,
                                isAdded: isAlreadyAdded(item),
                                isSelected: selectedItems.contains(item.id),
                                onAdd: { addItem(item) },
                                onToggleSelect: {
                                    if selectedItems.contains(item.id) {
                                        selectedItems.remove(item.id)
                                    } else {
                                        selectedItems.insert(item.id)
                                    }
                                }
                            )
                        } else {
                            LibraryItemRow(
                                item: item,
                                isAdded: isAlreadyAdded(item),
                                onAdd: { addItem(item) }
                            )
                        }
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
            if libraryStore.isUsingBundledData {
                Text("Offline")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
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

    private var bulkAddBar: some View {
        HStack {
            Text("\(selectedItems.count) selected")
                .font(.callout.bold())
            Spacer()
            Button("Add Selected") { showGroupPicker = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .popover(isPresented: $showGroupPicker) {
                    groupPickerContent
                }
            Button("Cancel") {
                selectedItems.removeAll()
                selectionMode = false
            }
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var existingGroups: [String] {
        selectedTab == .aliases ? aliasViewModel.groups : envViewModel.groups
    }

    private var groupPickerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add to group")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    Button(action: {
                        showGroupPicker = false
                        bulkAddSelected(groupOverride: nil)
                    }) {
                        Label("Use library categories", systemImage: "books.vertical")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                    .padding(.horizontal)
                    .padding(.vertical, 6)

                    if !existingGroups.isEmpty {
                        Divider().padding(.vertical, 4)

                        ForEach(existingGroups, id: \.self) { group in
                            Button(action: {
                                showGroupPicker = false
                                bulkAddSelected(groupOverride: group)
                            }) {
                                Label(group, systemImage: "folder")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.borderless)
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }

                    Divider().padding(.vertical, 4)

                    HStack {
                        TextField("New group name", text: $newGroupText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                let name = newGroupText.trimmingCharacters(in: .whitespaces)
                                guard !name.isEmpty else { return }
                                showGroupPicker = false
                                bulkAddSelected(groupOverride: name)
                                newGroupText = ""
                            }
                        Button("Add") {
                            let name = newGroupText.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            showGroupPicker = false
                            bulkAddSelected(groupOverride: name)
                            newGroupText = ""
                        }
                        .controlSize(.small)
                        .disabled(newGroupText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 260, maxHeight: 300)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: onBack) {
                Label("Back", systemImage: "chevron.left")
            }
            .help("Back to home")
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: {
                selectionMode.toggle()
                if !selectionMode { selectedItems.removeAll() }
            }) {
                Label("Select", systemImage: selectionMode ? "checkmark.circle.fill" : "checkmark.circle")
            }
            .help(selectionMode ? "Exit selection mode" : "Select multiple items to add")
        }
    }

    private var currentItemCount: Int {
        let categories = selectedTab == .aliases
            ? libraryStore.aliasCategories
            : libraryStore.envCategories
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

    private func addItem(_ item: LibraryItem, group: String? = nil) {
        let targetGroup = group ?? item.category
        switch item.type {
        case .alias:
            let success = aliasViewModel.addAlias(
                name: item.name,
                command: item.value,
                group: targetGroup
            )
            if success { addedItems.insert(item.name) }
        case .environment:
            let success = envViewModel.addVariable(
                name: item.name,
                value: item.value,
                group: targetGroup
            )
            if success { addedItems.insert(item.name) }
        }
    }

    private func bulkAddSelected(groupOverride: String?) {
        let allItems = (selectedTab == .aliases
            ? libraryStore.aliasCategories
            : libraryStore.envCategories
        ).flatMap(\.items)

        for item in allItems where selectedItems.contains(item.id) && !isAlreadyAdded(item) {
            addItem(item, group: groupOverride)
        }
        selectedItems.removeAll()
        selectionMode = false
    }
}

struct LibraryItemRow: View {
    let item: LibraryItem
    let isAdded: Bool
    var isSelected: Bool = false
    let onAdd: () -> Void
    var onToggleSelect: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            if let toggle = onToggleSelect {
                if isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .secondary)
                        .onTapGesture { toggle() }
                }
            }

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

            if onToggleSelect == nil {
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
        }
        .padding(.vertical, 2)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture {
            if let toggle = onToggleSelect, !isAdded { toggle() }
        }
    }
}
