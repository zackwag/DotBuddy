import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Picks `core.editor`, `diff.tool`, and `merge.tool` from what's installed. An empty selection unsets the key.
struct GitToolsSheet: View {
    @ObservedObject var viewModel: GitConfigViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editor = ""
    @State private var diffTool = ""
    @State private var mergeTool = ""
    @State private var editors: [GitEditorOption] = []
    @State private var diffTools: [GitDiffMergeTool] = []
    @State private var mergeTools: [GitDiffMergeTool] = []
    @State private var isDetecting = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    Picker("Editor", selection: $editor) {
                        Text("Not set").tag("")
                        ForEach(editors) { Text($0.name).tag($0.command) }
                        if !editor.isEmpty && !editors.contains(where: { $0.command == editor }) {
                            Text("Custom").tag(editor)
                        }
                    }
                    HStack {
                        TextField("Command", text: $editor)
                            .font(.body.monospaced())
                        Button("Browse...", action: browseForEditor)
                    }
                } header: {
                    sectionHeader("Editor", key: "core.editor")
                } footer: {
                    Text("Used for commit messages and interactive rebase. GUI editors need a wait flag so git waits for you to close the file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    toolPicker("Diff tool", selection: $diffTool, tools: diffTools)
                } header: {
                    sectionHeader("Diff Tool", key: "diff.tool")
                }

                Section {
                    toolPicker("Merge tool", selection: $mergeTool, tools: mergeTools)
                } header: {
                    sectionHeader("Merge Tool", key: "merge.tool")
                } footer: {
                    Text("Only tools git reports as installed are listed (`git difftool --tool-help`).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                if isDetecting {
                    ProgressView().controlSize(.small)
                    Text("Detecting installed tools...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Apply", action: apply)
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 520)
        .onAppear(perform: load)
    }

    private func sectionHeader(_ title: String, key: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(key)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
        }
    }

    private func toolPicker(_ label: String, selection: Binding<String>, tools: [GitDiffMergeTool]) -> some View {
        Picker(label, selection: selection) {
            Text("Not set").tag("")
            ForEach(tools) { tool in
                Text(tool.description.isEmpty ? tool.name : "\(tool.name) — \(tool.description)").tag(tool.name)
            }
            let current = selection.wrappedValue
            if !current.isEmpty && !tools.contains(where: { $0.name == current }) {
                Text("\(current) (not detected)").tag(current)
            }
        }
    }

    private func load() {
        editor = viewModel.value(section: "core", key: "editor") ?? ""
        diffTool = viewModel.value(section: "diff", key: "tool") ?? ""
        mergeTool = viewModel.value(section: "merge", key: "tool") ?? ""

        Task.detached {
            let editors = GitToolDetector.installedEditors()
            let diffTools = GitToolDetector.availableTools("difftool")
            let mergeTools = GitToolDetector.availableTools("mergetool")
            await MainActor.run {
                self.editors = editors
                self.diffTools = diffTools
                self.mergeTools = mergeTools
                self.isDetecting = false
            }
        }
    }

    private func apply() {
        let trimmedEditor = editor.trimmingCharacters(in: .whitespaces)
        viewModel.setValues([
            ("core", "editor", trimmedEditor.isEmpty ? nil : trimmedEditor),
            ("diff", "tool", diffTool.isEmpty ? nil : diffTool),
            ("merge", "tool", mergeTool.isEmpty ? nil : mergeTool),
        ])
        dismiss()
    }

    private func browseForEditor() {
        let panel = NSOpenPanel()
        panel.title = "Choose an Editor"
        panel.message = "Pick an app or a command-line executable."
        panel.allowedContentTypes = [.application, .unixExecutable]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            editor = GitToolDetector.editorCommand(forFileAt: url)
        }
    }
}
