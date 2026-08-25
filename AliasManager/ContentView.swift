import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: AliasViewModel
    var onBack: () -> Void
    @State private var isFormVisible = false
    @State private var editingAlias: Alias?
    @State private var aliasName = ""
    @State private var aliasCommand = ""
    @State private var aliasGroup = ""
    @State private var aliasToDelete: Alias?
    @State private var showDeleteConfirmation = false
    @State private var showSaveConfirmation = false
    @State private var showDiscardConfirmation = false
    @State private var showImportPicker = false
    @State private var showFilePicker = false
    @State private var showCreateConfirmation = false
    @State private var importedCount: Int?
    @State private var collapsedGroups: Set<String> = []
    @State private var renamingGroup: String?
    @State private var renameText = ""
    @State private var showLibrary = false

    var body: some View {
        Group {
            if viewModel.hasFile {
                mainContent
            } else {
                noFileState
            }
        }
        .toolbar { toolbarContent }
        .navigationTitle("DotBuddy — Aliases")
        .navigationSubtitle(viewModel.fileName)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .alert("Delete Alias", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let alias = aliasToDelete {
                    viewModel.deleteAlias(alias)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(aliasToDelete?.name ?? "")'?")
        }
        .alert("Save Changes", isPresented: $showSaveConfirmation) {
            Button("Save") { viewModel.saveChanges() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save all changes to \(viewModel.fileName)?")
        }
        .alert("Discard Changes", isPresented: $showDiscardConfirmation) {
            Button("Discard", role: .destructive) { viewModel.discardChanges() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All unsaved changes will be lost.")
        }
        .alert("Saved", isPresented: $viewModel.showSourceReminder) {
            Button("OK") {}
            Button("Don't show again", role: .cancel) {
                viewModel.suppressReminder()
            }
        } message: {
            Text("Aliases saved. To apply changes in your current terminal, run:\n\n\(viewModel.sourceCommand)\n\nOr ensure this file is sourced in your shell config and open a new terminal.")
        }
        .alert("Import Complete", isPresented: Binding(
            get: { importedCount != nil },
            set: { if !$0 { importedCount = nil } }
        )) {
            Button("OK") { importedCount = nil }
        } message: {
            Text("\(importedCount ?? 0) new alias\(importedCount == 1 ? "" : "es") imported.")
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.plainText, .unixExecutable],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                let count = viewModel.importAliases(from: url)
                if count > 0 { importedCount = count }
            }
        }
        .sheet(isPresented: $showLibrary) {
            LibrarySheetView(
                type: .alias,
                existingNames: Set(viewModel.workingAliases.map(\.name))
            ) { item in
                viewModel.addAlias(name: item.name, command: item.value, group: item.category)
            }
        }
        .onChange(of: showFilePicker) { _, show in
            if show {
                showFilePicker = false
                DispatchQueue.main.async {
                    openAliasFilePicker()
                }
            }
        }
    }

    private var noFileState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("No alias file selected")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Choose an existing file or create a new one.")
                .font(.callout)
                .foregroundStyle(.tertiary)
            HStack(spacing: 12) {
                Button("Select File...") {
                    showFilePicker = true
                }
                Button("Create Default") {
                    showCreateConfirmation = true
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .alert("Create Alias File", isPresented: $showCreateConfirmation) {
            Button("Create") { viewModel.createDefault() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will create a new file at:\n\n~/.aliases.zsh\n\nYou'll need to add `source ~/.aliases.zsh` to your shell config for these aliases to take effect.")
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if isFormVisible {
                AliasFormView(
                    aliasName: $aliasName,
                    aliasCommand: $aliasCommand,
                    aliasGroup: $aliasGroup,
                    existingGroups: viewModel.groups,
                    isEditing: editingAlias != nil,
                    onSubmit: submitForm,
                    onCancel: cancelForm
                )
                Divider()
            }

            if viewModel.displayedAliases.isEmpty {
                emptyState
            } else {
                aliasList
            }

            Divider()
            statusBar
        }
        .searchable(text: $viewModel.searchText, prompt: "Search aliases")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            if viewModel.searchText.isEmpty {
                Text("No aliases yet")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Click the + button to add your first alias.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                Text("No matching aliases")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var aliasList: some View {
        List {
            ForEach(viewModel.groupedAliases, id: \.group) { section in
                let groupKey = section.group
                let title = groupKey.isEmpty ? "Ungrouped" : groupKey

                DisclosureGroup(
                    isExpanded: Binding(
                        get: { !collapsedGroups.contains(groupKey) },
                        set: { isExpanded in
                            if isExpanded {
                                collapsedGroups.remove(groupKey)
                            } else {
                                collapsedGroups.insert(groupKey)
                            }
                        }
                    )
                ) {
                    ForEach(section.aliases) { alias in
                        AliasRowView(
                            alias: alias,
                            onEdit: { beginEditing(alias) },
                            onDelete: {
                                aliasToDelete = alias
                                showDeleteConfirmation = true
                            }
                        )
                    }
                    .onMove { indices, destination in
                        viewModel.moveAliases(in: groupKey, from: indices, to: destination)
                    }
                } label: {
                    HStack {
                        if renamingGroup == groupKey {
                            TextField("Group name", text: $renameText, onCommit: {
                                commitRename(from: groupKey)
                            })
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 200)

                            Button("Done") { commitRename(from: groupKey) }
                                .controlSize(.small)

                            Button("Cancel") { renamingGroup = nil }
                                .controlSize(.small)
                        } else {
                            Text(title)
                                .font(.headline)

                            if !groupKey.isEmpty {
                                Button(action: { beginRenaming(groupKey) }) {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .help("Rename group")
                            }
                        }
                    }
                    .contextMenu {
                        if !groupKey.isEmpty {
                            Button("Rename Group...") { beginRenaming(groupKey) }
                        }
                    }
                }
            }
        }
        .alternatingRowBackgrounds()
    }

    private var statusBar: some View {
        HStack {
            if viewModel.hasUnsavedChanges {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.orange)
                Text("Unsaved changes")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                Text("All changes saved")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.hasUnsavedChanges {
                Button("Discard") {
                    showDiscardConfirmation = true
                }
                .controlSize(.small)

                Button("Save") {
                    showSaveConfirmation = true
                }
                .keyboardShortcut("s", modifiers: .command)
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
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

        ToolbarItem(placement: .primaryAction) {
            Button(action: beginAdding) {
                Label("Add Alias", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .help("Add a new alias (Cmd+N)")
            .disabled(!viewModel.hasFile)
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: { showImportPicker = true }) {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("i", modifiers: .command)
            .help("Import aliases from a file (Cmd+I)")
            .disabled(!viewModel.hasFile)
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: { showLibrary = true }) {
                Label("Library", systemImage: "book.closed")
            }
            .help("Browse alias suggestions")
            .disabled(!viewModel.hasFile)
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: { viewModel.sortOrder.toggle(); viewModel.applySort() }) {
                Label("Sort", systemImage: viewModel.sortOrder.systemImage)
            }
            .help("Sort aliases by name")
            .disabled(!viewModel.hasFile)
        }

        ToolbarItem(placement: .automatic) {
            Button(action: { showFilePicker = true }) {
                Label("Change File", systemImage: "folder")
            }
            .help("Select a different alias file")
        }
    }

    private func beginAdding() {
        editingAlias = nil
        aliasName = ""
        aliasCommand = ""
        aliasGroup = ""
        isFormVisible = true
    }

    private func beginEditing(_ alias: Alias) {
        editingAlias = alias
        aliasName = alias.name
        aliasCommand = alias.command
        aliasGroup = alias.group
        isFormVisible = true
    }

    private func submitForm() {
        let success: Bool
        if let editing = editingAlias {
            success = viewModel.updateAlias(id: editing.id, name: aliasName, command: aliasCommand, group: aliasGroup)
        } else {
            success = viewModel.addAlias(name: aliasName, command: aliasCommand, group: aliasGroup)
        }

        if success {
            cancelForm()
        }
    }

    private func cancelForm() {
        isFormVisible = false
        editingAlias = nil
        aliasName = ""
        aliasCommand = ""
        aliasGroup = ""
    }

    private func beginRenaming(_ group: String) {
        renamingGroup = group
        renameText = group
    }

    private func commitRename(from oldGroup: String) {
        let newName = renameText.trimmingCharacters(in: .whitespaces)
        if !newName.isEmpty && newName != oldGroup {
            viewModel.renameGroup(from: oldGroup, to: newName)
        }
        renamingGroup = nil
    }

    private func openAliasFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Select Alias File"
        panel.allowedContentTypes = [.plainText, .unixExecutable]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.selectFile(url: url)
        }
    }
}
