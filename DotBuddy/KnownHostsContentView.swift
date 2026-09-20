import AppKit
import SwiftUI

struct KnownHostsContentView: View {
    @ObservedObject var viewModel: KnownHostsViewModel
    var onBack: () -> Void
    @State var hostToDelete: KnownHost?
    @State var showDeleteConfirmation = false
    @State var showSaveConfirmation = false
    @State var showDiscardConfirmation = false
    @State var showFilePicker = false
    @State var selectionMode = false
    @State var selectedHosts: Set<UUID> = []
    @State var showBulkDeleteConfirmation = false
    @State var showRestoreConfirmation = false
    @State var showBackConfirmation = false
    @Environment(\.undoManager) var undoManager

    var body: some View {
        content
            .onAppear { viewModel.undoManager = undoManager }
            .onChange(of: undoManager) { _, newValue in viewModel.undoManager = newValue }
            .onKeyPress(.escape) { handleEscape() }
            .onKeyPress(.delete) { handleDelete() }
            .onKeyPress(.deleteForward) { handleDelete() }
    }

    var content: some View {
        Group {
            if viewModel.hasFile {
                mainContent
            } else {
                noFileState
            }
        }
        .toolbar { toolbarContent }
        .navigationTitle("DotBuddy — Known Hosts")
        .navigationSubtitle(viewModel.fileName)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .alert("Remove Host", isPresented: $showDeleteConfirmation) {
            Button("Remove", role: .destructive) {
                if let host = hostToDelete {
                    viewModel.deleteHost(host)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove '\(hostToDelete?.displayName ?? "")'?")
        }
        .alert("Remove Selected", isPresented: $showBulkDeleteConfirmation) {
            Button("Remove \(selectedHosts.count)", role: .destructive) {
                viewModel.bulkDelete(selectedHosts)
                selectedHosts.removeAll()
                selectionMode = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove \(selectedHosts.count) known host\(selectedHosts.count == 1 ? "" : "s")?")
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
    }

    var noFileState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "key.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("No known_hosts file selected")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Choose an existing file or use the default.")
                .font(.callout)
                .foregroundStyle(.tertiary)
            HStack(spacing: 12) {
                Button("Select File...") {
                    showFilePicker = true
                }
                Button("Use Default") {
                    viewModel.useDefault()
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    var mainContent: some View {
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

            if viewModel.displayedHosts.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "key")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    if viewModel.searchText.isEmpty {
                        Text("No known hosts")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No matching hosts")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(viewModel.displayedHosts) { host in
                        HStack(spacing: 8) {
                            if selectionMode {
                                Image(systemName: selectedHosts.contains(host.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedHosts.contains(host.id) ? .blue : .secondary)
                                    .onTapGesture { toggleSelection(host.id) }
                            }
                            KnownHostRowView(
                                host: host,
                                onDelete: {
                                    hostToDelete = host
                                    showDeleteConfirmation = true
                                }
                            )
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectionMode { toggleSelection(host.id) }
                        }
                    }
                }
                .alternatingRowBackgrounds()
            }

            Divider()
            if selectionMode && !selectedHosts.isEmpty {
                knownHostsBulkBar
            } else {
                statusBar
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search known hosts")
    }

    var knownHostsBulkBar: some View {
        HStack(spacing: 10) {
            Text("\(selectedHosts.count) selected")
                .font(.callout.bold())
                .foregroundStyle(.secondary)

            Divider().frame(height: 16)

            Button(role: .destructive, action: { showBulkDeleteConfirmation = true }) {
                Label("Remove", systemImage: "trash")
            }
            .controlSize(.small)

            Spacer()

            Button("Done") {
                selectedHosts.removeAll()
                selectionMode = false
            }
            .controlSize(.small)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
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

            let hashedCount = viewModel.workingHosts.filter(\.isHashed).count
            if hashedCount > 0 {
                Text("\(viewModel.workingHosts.count) hosts (\(hashedCount) hashed)")
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

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
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
            Button(action: {
                selectionMode.toggle()
                if !selectionMode { selectedHosts.removeAll() }
            }) {
                Label("Select", systemImage: selectionMode ? "checkmark.circle.fill" : "checkmark.circle")
            }
            .help(selectionMode ? "Exit selection mode" : "Select multiple hosts")
            .disabled(!viewModel.hasFile)
        }

        if selectionMode {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    let allIds = Set(viewModel.displayedHosts.map(\.id))
                    if selectedHosts == allIds {
                        selectedHosts.removeAll()
                    } else {
                        selectedHosts = allIds
                    }
                }) {
                    let allSelected = !viewModel.displayedHosts.isEmpty && selectedHosts == Set(viewModel.displayedHosts.map(\.id))
                    Label(allSelected ? "Deselect All" : "Select All",
                          systemImage: allSelected ? "minus.circle" : "checklist.checked")
                }
                .help("Select or deselect all visible hosts")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: { viewModel.sortOrder.toggle(); viewModel.applySort() }) {
                Label("Sort", systemImage: viewModel.sortOrder.systemImage)
            }
            .help("Sort hosts by name")
            .disabled(!viewModel.hasFile)
        }

        ToolbarItem(placement: .automatic) {
            Menu {
                Button("Select File...") { showFilePicker = true }
            } label: {
                Label("Change File", systemImage: "folder")
            }
            .help("Select a different known_hosts file")
        }
    }

    func toggleSelection(_ id: UUID) {
        if selectedHosts.contains(id) {
            selectedHosts.remove(id)
        } else {
            selectedHosts.insert(id)
        }
    }

    func handleEscape() -> KeyPress.Result {
        if selectionMode {
            selectedHosts.removeAll()
            selectionMode = false
            return .handled
        }
        if !viewModel.searchText.isEmpty {
            viewModel.searchText = ""
            return .handled
        }
        return .ignored
    }

    func handleDelete() -> KeyPress.Result {
        guard selectionMode, !selectedHosts.isEmpty else { return .ignored }
        showBulkDeleteConfirmation = true
        return .handled
    }

    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Select Known Hosts File"
        panel.allowedContentTypes = [.item]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh")

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.selectFile(url: url)
        }
    }
}
