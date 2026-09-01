import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension ContentView {
    func beginAdding() {
        editingAlias = nil
        aliasName = ""
        aliasCommand = ""
        aliasGroup = ""
        isFormVisible = true
    }

    func beginEditing(_ alias: Alias) {
        editingAlias = alias
        aliasName = alias.name
        aliasCommand = alias.command
        aliasGroup = alias.group
        isFormVisible = true
    }

    func submitForm() {
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

    func cancelForm() {
        isFormVisible = false
        editingAlias = nil
        aliasName = ""
        aliasCommand = ""
        aliasGroup = ""
        aliasShadowWarning = nil
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
        if selectedAliases.contains(id) {
            selectedAliases.remove(id)
        } else {
            selectedAliases.insert(id)
        }
    }

    func exportAliases() {
        let ids = selectionMode && !selectedAliases.isEmpty ? selectedAliases : nil
        let content = viewModel.exportContent(for: ids)
        let panel = NSSavePanel()
        panel.title = "Export Aliases"
        panel.nameFieldStringValue = "aliases.zsh"
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
        if showReplaceBar {
            showReplaceBar = false
            replaceFind = ""
            replaceWith = ""
            return .handled
        }
        if selectionMode {
            selectedAliases.removeAll()
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
        guard selectionMode, !selectedAliases.isEmpty else { return .ignored }
        showBulkDeleteConfirmation = true
        return .handled
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                let count = viewModel.importAliases(from: url)
                if count > 0 { importedCount = count }
            }
        }
        return true
    }

    func openAliasFilePicker() {
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
