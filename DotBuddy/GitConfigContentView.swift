import AppKit
import SwiftUI

struct GitConfigContentView: View {
    @ObservedObject var viewModel: GitConfigViewModel
    var onBack: () -> Void
    @State private var entryToDelete: GitConfigEntry?
    @State private var showDeleteConfirmation = false
    @State private var showSaveConfirmation = false
    @State private var showDiscardConfirmation = false
    @State private var showRestoreConfirmation = false
    @State private var showBackConfirmation = false
    @State private var showForm = false
    @State private var editingID: UUID?
    @State private var formSection = ""
    @State private var formKey = ""
    @State private var formValue = ""
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        content
            .onAppear { viewModel.undoManager = undoManager }
            .onChange(of: undoManager) { _, newValue in viewModel.undoManager = newValue }
            .onKeyPress(.escape) { handleEscape() }
    }

    private var content: some View {
        Group {
            if viewModel.hasFile {
                mainContent
            } else {
                noFileState
            }
        }
        .toolbar { toolbarContent }
        .navigationTitle("DotBuddy — Git Config")
        .navigationSubtitle(viewModel.fileName)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .alert("Remove Entry", isPresented: $showDeleteConfirmation) {
            Button("Remove", role: .destructive) {
                if let entry = entryToDelete {
                    viewModel.deleteEntry(entry)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove '\(entryToDelete.map { "\($0.section).\($0.key)" } ?? "")'?")
        }
        .alert("Save Changes", isPresented: $showSaveConfirmation) {
            Button("Save") { viewModel.saveChanges() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save all changes to \(viewModel.fileName)? Comments in the file will not be preserved; a .bak backup is kept.")
        }
        .alert("Discard Changes", isPresented: $showDiscardConfirmation) {
            Button("Discard", role: .destructive) { viewModel.discardChanges() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All unsaved changes will be lost.")
        }
        .alert("Restore Backup", isPresented: $showRestoreConfirmation) {
            Button("Restore", role: .destructive) { viewModel.restoreFromBackup() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will replace the current file with the last saved backup. Unsaved changes will be lost.")
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

    private var noFileState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("No git config file selected")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Choose an existing file or use your global ~/.gitconfig.")
                .font(.callout)
                .foregroundStyle(.tertiary)
            HStack(spacing: 12) {
                Button("Select File...") { openFilePicker() }
                Button("Use Default") { viewModel.useDefault() }
                    .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if viewModel.fileChangedExternally {
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

            if showForm {
                entryForm
                Divider()
            }

            if viewModel.displayedSections.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text(viewModel.searchText.isEmpty ? "No git config entries" : "No matching entries")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(viewModel.displayedSections, id: \.section) { group in
                        Section {
                            ForEach(group.entries) { entry in
                                GitConfigRowView(
                                    entry: entry,
                                    onEdit: { beginEdit(entry) },
                                    onDuplicate: { viewModel.duplicateEntry(entry) },
                                    onDelete: {
                                        entryToDelete = entry
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                        } header: {
                            Text("[\(group.section)]")
                                .font(.callout.monospaced().bold())
                        }
                    }
                }
                .alternatingRowBackgrounds()
            }

            Divider()
            statusBar
        }
        .searchable(text: $viewModel.searchText, prompt: "Search git config")
    }

    private var isFormValid: Bool {
        GitConfigFileManager.isValidSection(formSection) && GitConfigFileManager.isValidKey(formKey)
    }

    private var entryForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                TextField("Section (e.g. user, remote \"origin\")", text: $formSection)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 140, maxWidth: 220)
                    .overlay(alignment: .trailing) {
                        if !viewModel.sections.isEmpty {
                            Menu {
                                ForEach(viewModel.sections, id: \.self) { section in
                                    Button(section) { formSection = section }
                                }
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .fixedSize()
                            .padding(.trailing, 4)
                            .help("Choose an existing section")
                        }
                    }

                TextField("Key", text: $formKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .frame(minWidth: 100, maxWidth: 160)

                TextField("Value", text: $formValue)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .onSubmit { if isFormValid { submitForm() } }

                Button(editingID == nil ? "Add" : "Update", action: submitForm)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!isFormValid)

                Button("Cancel", action: closeForm)
            }

            if !formSection.isEmpty && !GitConfigFileManager.isValidSection(formSection) {
                Text("Section must be letters, digits, '-' or '.', optionally followed by a quoted subsection.")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !formKey.isEmpty && !GitConfigFileManager.isValidKey(formKey) {
                Text("Key must start with a letter and contain only letters, digits or '-'.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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

            Text("\(viewModel.workingEntries.count) entries in \(viewModel.sections.count) sections")
                .font(.caption)
                .foregroundStyle(.tertiary)

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
                Button("Discard") { showDiscardConfirmation = true }
                    .controlSize(.small)

                Button("Save") { showSaveConfirmation = true }
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
            Button(action: {
                if viewModel.hasUnsavedChanges {
                    showBackConfirmation = true
                } else {
                    onBack()
                }
            }) {
                Label("Back", systemImage: "chevron.left")
            }
            .help("Back to home")
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: beginAdd) {
                Label("Add", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .help("Add a config entry (Cmd+N)")
            .disabled(!viewModel.hasFile)
        }

        ToolbarItem(placement: .automatic) {
            Menu {
                Button("Use Default") { viewModel.useDefault() }
                Button("Select File...") { openFilePicker() }
            } label: {
                Label("Change File", systemImage: "folder")
            }
            .help("Select a different git config file")
        }
    }

    private func beginAdd() {
        editingID = nil
        formSection = ""
        formKey = ""
        formValue = ""
        showForm = true
    }

    private func beginEdit(_ entry: GitConfigEntry) {
        editingID = entry.id
        formSection = entry.section
        formKey = entry.key
        formValue = entry.value
        showForm = true
    }

    private func submitForm() {
        viewModel.saveEntry(id: editingID, section: formSection, key: formKey, value: formValue)
        closeForm()
    }

    private func closeForm() {
        showForm = false
        editingID = nil
    }

    private func handleEscape() -> KeyPress.Result {
        if showForm {
            closeForm()
            return .handled
        }
        if !viewModel.searchText.isEmpty {
            viewModel.searchText = ""
            return .handled
        }
        return .ignored
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Select Git Config File"
        panel.allowedContentTypes = [.item]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.selectFile(url: url)
        }
    }
}

private struct GitConfigRowView: View {
    let entry: GitConfigEntry
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var isRowHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Text(entry.key)
                .font(.subheadline.monospaced().bold())
            Text("=")
                .foregroundStyle(.tertiary)
            Text(entry.value.isEmpty ? "(empty)" : entry.value)
                .font(.subheadline.monospaced())
                .foregroundStyle(entry.value.isEmpty ? .tertiary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(entry.value)

            Spacer()

            if isRowHovered {
                HoverButton(icon: "pencil", hoverColor: .accentColor, action: onEdit, help: "Edit entry")
                HoverButton(icon: "doc.on.doc", hoverColor: .accentColor, action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.value, forType: .string)
                }, help: "Copy value")
                HoverButton(icon: "plus.square.on.square", hoverColor: .accentColor, action: onDuplicate, help: "Duplicate entry")
                HoverButton(icon: "trash", hoverColor: .red, action: onDelete, help: "Remove entry")
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
        .onHover { isRowHovered = $0 }
    }
}
