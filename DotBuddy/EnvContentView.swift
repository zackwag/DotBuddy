import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct EnvContentView: View {
    @ObservedObject var viewModel: EnvViewModel
    @ObservedObject var libraryStore: LibraryStore
    var onBack: () -> Void
    @State var isFormVisible = false
    @State var editingVariable: EnvVariable?
    @State var varName = ""
    @State var varValue = ""
    @State var varGroup = ""
    @State var variableToDelete: EnvVariable?
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
    @State var selectedVariables: Set<UUID> = []
    @State var showBulkDeleteConfirmation = false
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
        .navigationTitle("DotBuddy — Environment")
        .navigationSubtitle(viewModel.fileName)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .alert("Delete Variable", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let variable = variableToDelete {
                    viewModel.deleteVariable(variable)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(variableToDelete?.name ?? "")'?")
        }
        .alert("Delete Selected", isPresented: $showBulkDeleteConfirmation) {
            Button("Delete \(selectedVariables.count)", role: .destructive) {
                viewModel.bulkDelete(selectedVariables)
                selectedVariables.removeAll()
                selectionMode = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(selectedVariables.count) variable\(selectedVariables.count == 1 ? "" : "s")?")
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
                Variables saved. To apply changes in your current terminal, run:\
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
                Text("\(importedCount ?? 0) new variable\(importedCount == 1 ? "" : "s") imported.")
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
                    let count = viewModel.importVariables(from: url)
                    if count > 0 { importedCount = count }
                }
            }
            .sheet(isPresented: $showLibrary) {
                LibrarySheetView(
                    type: .environment,
                    existingNames: Set(viewModel.workingVariables.map(\.name)),
                    existingGroups: viewModel.groups,
                    libraryStore: libraryStore
                ) { item in
                    viewModel.addVariable(name: item.name, value: item.value, group: item.category)
                }
            }
            .onChange(of: showFilePicker) { _, show in
                if show {
                    showFilePicker = false
                    DispatchQueue.main.async {
                        openFilePicker()
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
                    viewModel.replaceInValues(find: replaceFind, replaceWith: replaceWith)
                    showReplaceBar = false
                    replaceFind = ""
                    replaceWith = ""
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                let matchCount = viewModel.workingVariables.filter { $0.value.contains(replaceFind) }.count
                Text("This will remove '\(replaceFind)' from \(matchCount) value\(matchCount == 1 ? "" : "s"). This cannot be undone with Replace.")
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
            Text("No env file selected")
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
        .alert("Create Environment File", isPresented: $showCreateConfirmation) {
            Button("Create") { viewModel.createDefault() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("""
            This will create a new file at:\n\n~/.env.zsh\n\n\
            You'll need to add `source ~/.env.zsh` to your shell config \
            for these variables to take effect.
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
                EnvFormView(
                    itemName: $varName,
                    itemValue: $varValue,
                    itemGroup: $varGroup,
                    existingGroups: viewModel.groups,
                    isEditing: editingVariable != nil,
                    onSubmit: submitForm,
                    onCancel: cancelForm,
                    nameLabel: "Variable name",
                    valueLabel: "Value"
                )
                Divider()
            }

            if viewModel.displayedVariables.isEmpty {
                emptyState
            } else {
                variableList
            }

            Divider()
            if selectionMode && !selectedVariables.isEmpty {
                BulkActionBar(
                    selectedCount: selectedVariables.count,
                    existingGroups: viewModel.groups,
                    onEnable: {
                        viewModel.bulkSetEnabled(selectedVariables, enabled: true)
                        selectedVariables.removeAll()
                        selectionMode = false
                    },
                    onDisable: {
                        viewModel.bulkSetEnabled(selectedVariables, enabled: false)
                        selectedVariables.removeAll()
                        selectionMode = false
                    },
                    onDelete: { showBulkDeleteConfirmation = true },
                    onSetGroup: { group in
                        viewModel.bulkSetGroup(selectedVariables, group: group)
                        selectedVariables.removeAll()
                        selectionMode = false
                    },
                    onSuggest: {
                        let items = viewModel.workingVariables.filter { selectedVariables.contains($0.id) }
                        Self.openSuggestIssue(variables: items)
                    },
                    onCancel: {
                        selectedVariables.removeAll()
                        selectionMode = false
                    }
                )
            } else {
                statusBar
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search variables")
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            if viewModel.searchText.isEmpty {
                Text("No environment variables yet")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Click the + button to add your first variable.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                Text("No matching variables")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    var variableList: some View {
        List {
            ForEach(viewModel.groupedVariables, id: \.group) { section in
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
                    ForEach(section.variables) { variable in
                        HStack(spacing: 8) {
                            if selectionMode {
                                Image(systemName: selectedVariables.contains(variable.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedVariables.contains(variable.id) ? .blue : .secondary)
                                    .onTapGesture { toggleSelection(variable.id) }
                            }
                            EnvRowView(
                                variable: variable,
                                onEdit: { beginEditing(variable) },
                                onDelete: {
                                    variableToDelete = variable
                                    showDeleteConfirmation = true
                                },
                                onToggleSecret: { viewModel.toggleSecret(variable) },
                                onToggleEnabled: { viewModel.toggleEnabled(variable) },
                                onDuplicate: { viewModel.duplicateVariable(variable) }
                            )
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectionMode { toggleSelection(variable.id) }
                        }
                    }
                    .onMove { indices, destination in
                        viewModel.moveVariables(in: groupKey, from: indices, to: destination)
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

            let disabledCount = viewModel.workingVariables.filter { !$0.isEnabled }.count
            if disabledCount > 0 {
                Text("\(viewModel.workingVariables.count) variables (\(disabledCount) disabled)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text("\(viewModel.workingVariables.count) variables")
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
            let matchCount = replaceFind.isEmpty ? 0 : viewModel.workingVariables.filter { $0.value.contains(replaceFind) }.count
            Text("\(matchCount) match\(matchCount == 1 ? "" : "es")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70)
            Button("Replace All") {
                if replaceWith.isEmpty {
                    showReplaceConfirmation = true
                } else {
                    viewModel.replaceInValues(find: replaceFind, replaceWith: replaceWith)
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
