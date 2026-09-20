import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension SSHContentView {
    func beginAdding() {
        editingHost = nil
        hostPattern = ""
        hostHostname = ""
        hostUser = ""
        hostPort = ""
        hostIdentityFile = ""
        hostGroup = ""
        isFormVisible = true
    }

    func beginEditing(_ host: SSHHost) {
        editingHost = host
        hostPattern = host.hostPattern
        hostHostname = host.hostname
        hostUser = host.user
        hostPort = host.port
        hostIdentityFile = host.identityFile
        hostGroup = host.group
        isFormVisible = true
    }

    func submitForm() {
        let host = SSHHost(
            id: editingHost?.id ?? UUID(),
            hostPattern: hostPattern,
            hostname: hostHostname,
            user: hostUser,
            port: hostPort,
            identityFile: hostIdentityFile,
            group: hostGroup
        )
        let success = editingHost != nil
            ? viewModel.updateHost(host)
            : viewModel.addHost(host)

        if success {
            cancelForm()
        }
    }

    func cancelForm() {
        isFormVisible = false
        editingHost = nil
        hostPattern = ""
        hostHostname = ""
        hostUser = ""
        hostPort = ""
        hostIdentityFile = ""
        hostGroup = ""
    }

    func beginRenaming(_ group: String) {
        renamingGroup = group
        renameText = group
    }

    func commitRename(from oldGroup: String) {
        let newName = renameText.trimmingCharacters(in: .whitespaces)
        if !newName.isEmpty && newName != oldGroup {
            viewModel.renameGroup(from: oldGroup, to: newName)
        }
        renamingGroup = nil
    }

    func toggleSelection(_ id: UUID) {
        if selectedHosts.contains(id) {
            selectedHosts.remove(id)
        } else {
            selectedHosts.insert(id)
        }
    }

    func exportHosts() {
        let ids = selectionMode && !selectedHosts.isEmpty ? selectedHosts : nil
        let content = viewModel.exportContent(for: ids)
        let panel = NSSavePanel()
        panel.title = "Export SSH Config"
        panel.nameFieldStringValue = "config"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func handleEscape() -> KeyPress.Result {
        if isFormVisible {
            cancelForm()
            return .handled
        }
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
        panel.title = "Select SSH Config File"
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
