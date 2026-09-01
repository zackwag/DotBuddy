import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension EnvContentView {
    func beginAdding() {
        editingVariable = nil
        varName = ""
        varValue = ""
        varGroup = ""
        isFormVisible = true
    }

    func beginEditing(_ variable: EnvVariable) {
        editingVariable = variable
        varName = variable.name
        varValue = variable.value
        varGroup = variable.group
        isFormVisible = true
    }

    func submitForm() {
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

    func cancelForm() {
        isFormVisible = false
        editingVariable = nil
        varName = ""
        varValue = ""
        varGroup = ""
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
        if selectedVariables.contains(id) {
            selectedVariables.remove(id)
        } else {
            selectedVariables.insert(id)
        }
    }

    func exportVariables() {
        let ids = selectionMode && !selectedVariables.isEmpty ? selectedVariables : nil
        let content = viewModel.exportContent(for: ids)
        let panel = NSSavePanel()
        panel.title = "Export Variables"
        panel.nameFieldStringValue = "env.zsh"
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
            selectedVariables.removeAll()
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
        guard selectionMode, !selectedVariables.isEmpty else { return .ignored }
        showBulkDeleteConfirmation = true
        return .handled
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                let count = viewModel.importVariables(from: url)
                if count > 0 { importedCount = count }
            }
        }
        return true
    }

    func openFilePicker() {
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

    static func openSuggestIssue(variables: [EnvVariable]) {
        let json = variables.map { v in
            """
            {"name": "\(v.name)", "value": "\(v.value)", "description": "", "type": "environment", "category": ""}
            """
        }.joined(separator: ",\n")

        let body = """
        **Suggested environment variables:**

        ```json
        [
        \(json)
        ]
        ```

        **Category:** (e.g. Shell, Development, Path Extensions, etc.)

        **Description:** (optional context for these suggestions)
        """

        let title = "Library suggestion: \(variables.count) variable\(variables.count == 1 ? "" : "s")"
        openGitHubIssue(title: title, body: body, label: "library")
    }

    private static func openGitHubIssue(title: String, body: String, label: String) {
        var components = URLComponents(string: "https://github.com/zackwag/DotBuddy/issues/new")!
        components.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "body", value: body),
            URLQueryItem(name: "labels", value: label),
        ]
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }
}
