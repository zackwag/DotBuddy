import Foundation

struct GitConfigEntry: Identifiable, Equatable, Hashable {
    let id: UUID
    /// Raw header text between the brackets, e.g. `user` or `remote "origin"`.
    var section: String
    var key: String
    var value: String

    init(id: UUID = UUID(), section: String, key: String, value: String) {
        self.id = id
        self.section = section
        self.key = key
        self.value = value
    }
}

/// One-click tool setups, using the commands from VS Code's docs. Requires the `code` CLI on PATH.
extension GitConfigEntry {
    static let vsCodeEditor = [
        GitConfigEntry(section: "core", key: "editor", value: "code --wait"),
    ]

    static let vsCodeDiffTool = [
        GitConfigEntry(section: "diff", key: "tool", value: "vscode"),
        GitConfigEntry(section: "difftool \"vscode\"", key: "cmd", value: "code --wait --diff $LOCAL $REMOTE"),
    ]

    static let vsCodeMergeTool = [
        GitConfigEntry(section: "merge", key: "tool", value: "vscode"),
        GitConfigEntry(section: "mergetool \"vscode\"", key: "cmd", value: "code --wait --merge $REMOTE $LOCAL $BASE $MERGED"),
    ]
}
