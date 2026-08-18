import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct EnvContentView: View {
    @ObservedObject var viewModel: EnvViewModel
    var onBack: () -> Void
    @State private var isFormVisible = false
    @State private var editingVariable: EnvVariable?
    @State private var varName = ""
    @State private var varValue = ""
    @State private var varGroup = ""
    @State private var variableToDelete: EnvVariable?
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

    var body: some View {
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
            Text("Variables saved. To apply changes in your current terminal, run:\n\n\(viewModel.sourceCommand)\n\nOr ensure this file is sourced in your shell config and open a new terminal.")
        }
        .alert("Import Complete", isPresented: Binding(
            get: { importedCount != nil },
            set: { if !$0 { importedCount = nil } }
        )) {
            Button("OK") { importedCount = nil }
        } message: {
            Text("\(importedCount ?? 0) new variable\(importedCount == 1 ? "" : "s") imported.")
        }
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
        .onChange(of: showFilePicker) { _, show in
            if show {
                showFilePicker = false
                DispatchQueue.main.async {
                    openFilePicker()
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
            Text("This will create a new file at:\n\n~/.env.zsh\n\nYou'll need to add `source ~/.env.zsh` to your shell config for these variables to take effect.")
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if isFormVisible {
                EnvFormView(
                    varName: $varName,
                    varValue: $varValue,
                    varGroup: $varGroup,
                    existingGroups: viewModel.groups,
                    isEditing: editingVariable != nil,
                    onSubmit: submitForm,
                    onCancel: cancelForm
                )
                Divider()
            }

            if viewModel.displayedVariables.isEmpty {
                emptyState
            } else {
                variableList
            }

            Divider()
            statusBar
        }
        .searchable(text: $viewModel.searchText, prompt: "Search variables")
    }

    private var emptyState: some View {
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

    private var variableList: some View {
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
                        EnvRowView(
                            variable: variable,
                            onEdit: { beginEditing(variable) },
                            onDelete: {
                                variableToDelete = variable
                                showDeleteConfirmation = true
                            },
                            onToggleSecret: { viewModel.toggleSecret(variable) }
                        )
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
                Label("Add Variable", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .help("Add a new variable (Cmd+N)")
            .disabled(!viewModel.hasFile)
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: { showImportPicker = true }) {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("i", modifiers: .command)
            .help("Import variables from a file (Cmd+I)")
            .disabled(!viewModel.hasFile)
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: { viewModel.sortOrder.toggle(); viewModel.applySort() }) {
                Label("Sort", systemImage: viewModel.sortOrder.systemImage)
            }
            .help("Sort variables by name")
            .disabled(!viewModel.hasFile)
        }

        ToolbarItem(placement: .automatic) {
            Button(action: { showFilePicker = true }) {
                Label("Change File", systemImage: "folder")
            }
            .help("Select a different env file")
        }
    }

    private func beginAdding() {
        editingVariable = nil
        varName = ""
        varValue = ""
        varGroup = ""
        isFormVisible = true
    }

    private func beginEditing(_ variable: EnvVariable) {
        editingVariable = variable
        varName = variable.name
        varValue = variable.value
        varGroup = variable.group
        isFormVisible = true
    }

    private func submitForm() {
        let success: Bool
        if let editing = editingVariable {
            success = viewModel.updateVariable(id: editing.id, name: varName, value: varValue, group: varGroup)
        } else {
            success = viewModel.addVariable(name: varName, value: varValue, group: varGroup)
        }

        if success {
            cancelForm()
        }
    }

    private func cancelForm() {
        isFormVisible = false
        editingVariable = nil
        varName = ""
        varValue = ""
        varGroup = ""
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

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Select Environment Variables File"
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
