import SwiftUI

struct LibrarySheetView: View {
    let type: LibraryItemType
    let existingNames: Set<String>
    var existingGroups: [String] = []
    @ObservedObject var libraryStore: LibraryStore
    let onAdd: (LibraryItem) -> Bool
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var addedItems: Set<String> = []
    @State private var selectionMode = false
    @State private var selectedItems: Set<UUID> = []
    @State private var showGroupPicker = false
    @State private var newGroupText = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if filteredCategories.isEmpty {
                emptyState
            } else {
                categoryList
            }
        }
        .frame(width: 500, height: 400)
    }

    private var header: some View {
        HStack {
            Text(type == .alias ? "Alias Library" : "Environment Library")
                .font(.headline)
            Spacer()
            Button(action: {
                selectionMode.toggle()
                if !selectionMode { selectedItems.removeAll() }
            }) {
                Image(systemName: selectionMode ? "checkmark.circle.fill" : "checkmark.circle")
            }
            .buttonStyle(.borderless)
            .help(selectionMode ? "Exit selection mode" : "Select multiple items")
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
    }

    private var filteredCategories: [LibraryCategory] {
        let categories = type == .alias
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
        VStack(spacing: 0) {
            List {
                ForEach(filteredCategories) { category in
                    Section {
                        ForEach(category.items) { item in
                            if selectionMode {
                                LibraryItemRow(
                                    item: item,
                                    isAdded: existingNames.contains(item.name) || addedItems.contains(item.name),
                                    isSelected: selectedItems.contains(item.id),
                                    onAdd: {
                                        if onAdd(item) {
                                            addedItems.insert(item.name)
                                        }
                                    },
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
                                    isAdded: existingNames.contains(item.name) || addedItems.contains(item.name),
                                    onAdd: {
                                        if onAdd(item) {
                                            addedItems.insert(item.name)
                                        }
                                    }
                                )
                            }
                        }
                    } header: {
                        Label(category.name, systemImage: category.icon)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search")

            if selectionMode && !selectedItems.isEmpty {
                Divider()
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
        }
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

    private func bulkAddSelected(groupOverride: String?) {
        let categories = type == .alias
            ? libraryStore.aliasCategories
            : libraryStore.envCategories
        let allItems = categories.flatMap(\.items)

        for item in allItems where selectedItems.contains(item.id) {
            let alreadyAdded = existingNames.contains(item.name) || addedItems.contains(item.name)
            if !alreadyAdded {
                let itemToAdd = groupOverride.map {
                    LibraryItem(name: item.name, value: item.value, description: item.description, type: item.type, category: $0)
                } ?? item
                if onAdd(itemToAdd) {
                    addedItems.insert(item.name)
                }
            }
        }
        selectedItems.removeAll()
        selectionMode = false
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No matching items")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
