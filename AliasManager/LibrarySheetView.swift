import SwiftUI

struct LibrarySheetView: View {
    let type: LibraryItemType
    let existingNames: Set<String>
    let onAdd: (LibraryItem) -> Bool
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var addedItems: Set<String> = []

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
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
    }

    private var filteredCategories: [LibraryCategory] {
        let categories = type == .alias
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
                            isAdded: existingNames.contains(item.name) || addedItems.contains(item.name),
                            onAdd: {
                                if onAdd(item) {
                                    addedItems.insert(item.name)
                                }
                            }
                        )
                    }
                } header: {
                    Label(category.name, systemImage: category.icon)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search")
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
