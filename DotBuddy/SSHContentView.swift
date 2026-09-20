import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SSHContentView: View {
    @ObservedObject var viewModel: SSHViewModel
    var onBack: () -> Void
    @State var isFormVisible = false
    @State var editingHost: SSHHost?
    @State var hostPattern = ""
    @State var hostHostname = ""
    @State var hostUser = ""
    @State var hostPort = ""
    @State var hostIdentityFile = ""
    @State var hostGroup = ""
    @State var hostToDelete: SSHHost?
    @State var showDeleteConfirmation = false
    @State var showSaveConfirmation = false
    @State var showDiscardConfirmation = false
    @State var showFilePicker = false
    @State var showCreateConfirmation = false
    @State var collapsedGroups: Set<String> = []
    @State var renamingGroup: String?
    @State var renameText = ""
    @State var selectionMode = false
    @State var selectedHosts: Set<UUID> = []
    @State var showBulkDeleteConfirmation = false
    @State var showRestoreConfirmation = false
    @State var showBackConfirmation = false
    @State var showKeyGenerator = false
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
        .navigationTitle("DotBuddy — SSH Config")
        .navigationSubtitle(viewModel.fileName)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .alert("Delete Host", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let host = hostToDelete {
                    viewModel.deleteHost(host)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(hostToDelete?.hostPattern ?? "")'?")
        }
        .alert("Delete Selected", isPresented: $showBulkDeleteConfirmation) {
            Button("Delete \(selectedHosts.count)", role: .destructive) {
                viewModel.bulkDelete(selectedHosts)
                selectedHosts.removeAll()
                selectionMode = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(selectedHosts.count) host\(selectedHosts.count == 1 ? "" : "s")?")
        }
    }

    var contentWithAllAlerts: some View {
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
            .onChange(of: showFilePicker) { _, show in
                if show {
                    showFilePicker = false
                    DispatchQueue.main.async { openFilePicker() }
                }
            }
            .sheet(isPresented: $showKeyGenerator) {
                SSHKeyGeneratorView(sshViewModel: viewModel) {
                    showKeyGenerator = false
                }
            }
            .sheet(isPresented: $viewModel.showTestAllResults) {
                SSHTestAllResultsView(
                    results: viewModel.testAllResults,
                    isTesting: viewModel.isTestingAll,
                    onDismiss: { viewModel.showTestAllResults = false },
                    onDeleteHosts: { ids in
                        viewModel.bulkDelete(ids)
                        viewModel.testAllResults.removeAll { ids.contains($0.id) }
                    }
                )
            }
    }

    var noFileState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("No SSH config file selected")
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
        .alert("Create SSH Config", isPresented: $showCreateConfirmation) {
            Button("Create") { viewModel.createDefault() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will create a new file at:\n\n~/.ssh/config\n\nwith appropriate permissions (600).")
        }
    }

    var mainContent: some View {
        VStack(spacing: 0) {
            if viewModel.fileChangedExternally {
                fileChangedBanner
            }
            if isFormVisible {
                SSHHostFormView(
                    hostPattern: $hostPattern,
                    hostname: $hostHostname,
                    user: $hostUser,
                    port: $hostPort,
                    identityFile: $hostIdentityFile,
                    group: $hostGroup,
                    existingGroups: viewModel.groups,
                    isEditing: editingHost != nil,
                    onSubmit: submitForm,
                    onCancel: cancelForm
                )
                Divider()
            }

            if viewModel.displayedHosts.isEmpty {
                emptyState
            } else {
                hostList
            }

            Divider()
            if selectionMode && !selectedHosts.isEmpty {
                BulkActionBar(
                    selectedCount: selectedHosts.count,
                    existingGroups: viewModel.groups,
                    onEnable: {
                        viewModel.bulkSetEnabled(selectedHosts, enabled: true)
                        selectedHosts.removeAll()
                        selectionMode = false
                    },
                    onDisable: {
                        viewModel.bulkSetEnabled(selectedHosts, enabled: false)
                        selectedHosts.removeAll()
                        selectionMode = false
                    },
                    onDelete: { showBulkDeleteConfirmation = true },
                    onSetGroup: { group in
                        viewModel.bulkSetGroup(selectedHosts, group: group)
                        selectedHosts.removeAll()
                        selectionMode = false
                    },
                    onSuggest: nil,
                    onCancel: {
                        selectedHosts.removeAll()
                        selectionMode = false
                    }
                )
            } else {
                statusBar
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search hosts")
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "network")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            if viewModel.searchText.isEmpty {
                Text("No SSH hosts yet")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Click the + button to add your first host.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                Text("No matching hosts")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    var hostList: some View {
        List {
            ForEach(viewModel.groupedHosts, id: \.group) { section in
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
                    ForEach(section.hosts) { host in
                        HStack(spacing: 8) {
                            if selectionMode {
                                Image(systemName: selectedHosts.contains(host.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedHosts.contains(host.id) ? .blue : .secondary)
                                    .onTapGesture { toggleSelection(host.id) }
                            }
                            SSHHostRowView(
                                host: host,
                                connectionStatus: viewModel.connectionStatuses[host.id] ?? .idle,
                                onEdit: { beginEditing(host) },
                                onDelete: {
                                    hostToDelete = host
                                    showDeleteConfirmation = true
                                },
                                onToggleEnabled: { viewModel.toggleEnabled(host) },
                                onDuplicate: { viewModel.duplicateHost(host) },
                                onTestConnection: { viewModel.testConnection(for: host) }
                            )
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectionMode { toggleSelection(host.id) }
                        }
                    }
                    .onMove { indices, destination in
                        viewModel.moveHosts(in: groupKey, from: indices, to: destination)
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

            let disabledCount = viewModel.workingHosts.filter { !$0.isEnabled }.count
            if disabledCount > 0 {
                Text("\(viewModel.workingHosts.count) hosts (\(disabledCount) disabled)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text("\(viewModel.workingHosts.count) hosts")
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
