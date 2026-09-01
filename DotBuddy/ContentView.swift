import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: AliasViewModel
    @ObservedObject var libraryStore: LibraryStore
    var onBack: () -> Void
    @State var isFormVisible = false
    @State var editingAlias: Alias?
    @State var aliasName = ""
    @State var aliasCommand = ""
    @State var aliasGroup = ""
    @State var aliasToDelete: Alias?
    @State var showDeleteConfirmation = false
    @State var showSaveConfirmation = false
    @State var showDiscardConfirmation = false
    @State var showImportPicker = false
    @State var showFilePicker = false
    @State var showCreateConfirmation = false
    @State var importedCount: Int?
    @State var collapsedGroups: Set<String> = []
    @State var renamingGroup: String?
    @State var renameText = ""
    @State var showLibrary = false
    @State var selectionMode = false
    @State var selectedAliases: Set<UUID> = []
    @State var showBulkDeleteConfirmation = false
    @State var aliasShadowWarning: String?
    @State var showRestoreConfirmation = false
    @State var showBackConfirmation = false
    @State var showReplaceBar = false
    @State var replaceFind = ""
    @State var replaceWith = ""
    @State var showReplaceConfirmation = false
    @Environment(\.undoManager) var undoManager

    var body: some View {
        contentWithAllAlerts
            .onAppear { viewModel.undoManager = undoManager }
            .onChange(of: undoManager) { _, newValue in viewModel.undoManager = newValue }
            .onKeyPress(.escape) { handleEscape() }
            .onKeyPress(.delete) { handleDelete() }
            .onKeyPress(.deleteForward) { handleDelete() }
    }

    var baseContent: some View {
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
            let deps = aliasToDelete.map { viewModel.dependents(of: $0.name) } ?? []
            if deps.isEmpty {
                Text("Are you sure you want to delete '\(aliasToDelete?.name ?? "")'?")
            } else {
                Text("'\(aliasToDelete?.name ?? "")' is used by: \(deps.joined(separator: ", ")). Delete anyway?")
            }
        }
        .alert("Delete Selected", isPresented: $showBulkDeleteConfirmation) {
            Button("Delete \(selectedAliases.count)", role: .destructive) {
                viewModel.bulkDelete(selectedAliases)
                selectedAliases.removeAll()
                selectionMode = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(selectedAliases.count) alias\(selectedAliases.count == 1 ? "" : "es")?")
        }
    }

    var contentWithSaveAlerts: some View {
        baseContent
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
                Text("""
                Aliases saved. To apply changes in your current terminal, run:\
                \n\n\(viewModel.sourceCommand)\n\n\
                Or ensure this file is sourced in your shell config and open a new terminal.
                """)
            }
            .alert("Import Complete", isPresented: Binding(
                get: { importedCount != nil },
                set: { if !$0 { importedCount = nil } }
            )) {
                Button("OK") { importedCount = nil }
            } message: {
                Text("\(importedCount ?? 0) new alias\(importedCount == 1 ? "" : "es") imported.")
            }
    }

    var contentWithSheets: some View {
        contentWithSaveAlerts
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
                    existingNames: Set(viewModel.workingAliases.map(\.name)),
                    existingGroups: viewModel.groups,
                    libraryStore: libraryStore
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
            .alert("Restore Backup", isPresented: $showRestoreConfirmation) {
                Button("Restore", role: .destructive) { viewModel.restoreFromBackup() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will replace the current file with the last saved backup. Unsaved changes will be lost.")
            }
    }

    var contentWithAllAlerts: some View {
        contentWithSheets
            .alert("Replace with Empty", isPresented: $showReplaceConfirmation) {
                Button("Replace All", role: .destructive) {
                    viewModel.replaceInCommands(find: replaceFind, replaceWith: replaceWith)
                    showReplaceBar = false
                    replaceFind = ""
                    replaceWith = ""
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                let matchCount = viewModel.workingAliases.filter { $0.command.contains(replaceFind) }.count
                Text("This will remove '\(replaceFind)' from \(matchCount) command\(matchCount == 1 ? "" : "s"). This cannot be undone with Replace.")
            }
            .alert("Unsaved Changes", isPresented: $showBackConfirmation) {
                Button("Save & Go Back") {
                    viewModel.saveChanges()
                    onBack()
                }
                Button("Discard & Go Back", role: .destructive) {
                    viewModel.discardChanges()
                    onBack()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. What would you like to do?")
            }
    }

    var noFileState: some View {
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
            Text("""
            This will create a new file at:\n\n~/.aliases.zsh\n\n\
            You'll need to add `source ~/.aliases.zsh` to your shell config \
            for these aliases to take effect.
            """)
        }
    }

    var mainContent: some View {
        VStack(spacing: 0) {
            if viewModel.fileChangedExternally {
                fileChangedBanner
            }
            if showReplaceBar {
                replaceBar
            }
            if isFormVisible {
                AliasFormView(
                    itemName: $aliasName,
                    itemValue: $aliasCommand,
                    itemGroup: $aliasGroup,
                    existingGroups: viewModel.groups,
                    isEditing: editingAlias != nil,
                    onSubmit: submitForm,
                    onCancel: cancelForm,
                    nameLabel: "Alias name",
                    valueLabel: "Command",
                    shadowWarning: aliasShadowWarning
                )
                .onChange(of: aliasName) { _, name in
                    Task.detached { [viewModel] in
                        let warning = viewModel.shadowWarning(for: name)
                        await MainActor.run { aliasShadowWarning = warning }
                    }
                }
                Divider()
            }

            if viewModel.displayedAliases.isEmpty {
                emptyState
            } else {
                aliasList
            }

            Divider()
            if selectionMode && !selectedAliases.isEmpty {
                BulkActionBar(
                    selectedCount: selectedAliases.count,
                    existingGroups: viewModel.groups,
                    onEnable: {
                        viewModel.bulkSetEnabled(selectedAliases, enabled: true)
                        selectedAliases.removeAll()
                        selectionMode = false
                    },
                    onDisable: {
                        viewModel.bulkSetEnabled(selectedAliases, enabled: false)
                        selectedAliases.removeAll()
                        selectionMode = false
                    },
                    onDelete: { showBulkDeleteConfirmation = true },
                    onSetGroup: { group in
                        viewModel.bulkSetGroup(selectedAliases, group: group)
                        selectedAliases.removeAll()
                        selectionMode = false
                    },
                    onSuggest: {
                        let items = viewModel.workingAliases.filter { selectedAliases.contains($0.id) }
                        Self.openSuggestIssue(aliases: items)
                    },
                    onCancel: {
                        selectedAliases.removeAll()
                        selectionMode = false
                    }
                )
            } else {
                statusBar
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search aliases")
    }

    var emptyState: some View {
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

    var aliasList: some View {
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
                        HStack(spacing: 8) {
                            if selectionMode {
                                Image(systemName: selectedAliases.contains(alias.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedAliases.contains(alias.id) ? .blue : .secondary)
                                    .onTapGesture { toggleSelection(alias.id) }
                            }
                            AliasRowView(
                                alias: alias,
                                onEdit: { beginEditing(alias) },
                                onDelete: {
                                    aliasToDelete = alias
                                    showDeleteConfirmation = true
                                },
                                onToggleEnabled: { viewModel.toggleEnabled(alias) },
                                onDuplicate: { viewModel.duplicateAlias(alias) },
                                dependencies: viewModel.dependencies(of: alias)
                            )
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectionMode { toggleSelection(alias.id) }
                        }
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
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    var statusBar: some View {
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

            let disabledCount = viewModel.workingAliases.filter { !$0.isEnabled }.count
            if disabledCount > 0 {
                Text("\(viewModel.workingAliases.count) aliases (\(disabledCount) disabled)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text("\(viewModel.workingAliases.count) aliases")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if let filePath = viewModel.filePath {
                Button {
                    NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: "")
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Reveal in Finder")
            }

            if viewModel.hasBackup {
                Button("Restore Backup") { showRestoreConfirmation = true }
                    .controlSize(.small)
            }

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

    var replaceBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
                .foregroundStyle(.secondary)
            TextField("Find", text: $replaceFind)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 180)
            TextField("Replace with", text: $replaceWith)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 180)
            let matchCount = replaceFind.isEmpty ? 0 : viewModel.workingAliases.filter { $0.command.contains(replaceFind) }.count
            Text("\(matchCount) match\(matchCount == 1 ? "" : "es")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70)
            Button("Replace All") {
                if replaceWith.isEmpty {
                    showReplaceConfirmation = true
                } else {
                    viewModel.replaceInCommands(find: replaceFind, replaceWith: replaceWith)
                    showReplaceBar = false
                    replaceFind = ""
                    replaceWith = ""
                }
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .disabled(replaceFind.isEmpty || matchCount == 0)
            Button {
                showReplaceBar = false
                replaceFind = ""
                replaceWith = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }

    var fileChangedBanner: some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.blue)
            Text("File changed on disk.")
                .font(.callout)
            Spacer()
            Button("Reload") { viewModel.reloadFromDisk() }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
            Button("Dismiss") { viewModel.fileChangedExternally = false }
                .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.blue.opacity(0.1))
    }

}
