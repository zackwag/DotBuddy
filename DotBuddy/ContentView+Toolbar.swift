import SwiftUI

extension ContentView {
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
            Button(action: beginAdding) {
                Label("Add Alias", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .help("Add a new alias (Cmd+N)")
            .disabled(!viewModel.hasFile)
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: { showImportPicker = true }) {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("i", modifiers: .command)
            .help("Import aliases from a file (Cmd+I)")
            .disabled(!viewModel.hasFile)
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: exportAliases) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .keyboardShortcut("e", modifiers: .command)
            .help("Export aliases to a file (Cmd+E)")
            .disabled(!viewModel.hasFile || viewModel.workingAliases.isEmpty)
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: { showLibrary = true }) {
                Label("Library", systemImage: "book.closed")
            }
            .help("Browse alias suggestions")
            .disabled(!viewModel.hasFile)
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: {
                selectionMode.toggle()
                if !selectionMode { selectedAliases.removeAll() }
            }) {
                Label("Select", systemImage: selectionMode ? "checkmark.circle.fill" : "checkmark.circle")
            }
            .help(selectionMode ? "Exit selection mode" : "Select multiple aliases")
            .disabled(!viewModel.hasFile)
        }

        if selectionMode {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    let allIds = Set(viewModel.displayedAliases.map(\.id))
                    if selectedAliases == allIds {
                        selectedAliases.removeAll()
                    } else {
                        selectedAliases = allIds
                    }
                }) {
                    let allSelected = !viewModel.displayedAliases.isEmpty && selectedAliases == Set(viewModel.displayedAliases.map(\.id))
                    Label(allSelected ? "Deselect All" : "Select All",
                          systemImage: allSelected ? "minus.circle" : "checkmark.circle.badge.checkmark")
                }
                .help("Select or deselect all visible aliases")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: { showReplaceBar.toggle() }) {
                Label("Find & Replace", systemImage: "arrow.left.arrow.right")
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .help("Find and replace in commands (Cmd+Shift+H)")
            .disabled(!viewModel.hasFile)
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: { viewModel.sortOrder.toggle(); viewModel.applySort() }) {
                Label("Sort", systemImage: viewModel.sortOrder.systemImage)
            }
            .help("Sort aliases by name")
            .disabled(!viewModel.hasFile)
        }

        ToolbarItem(placement: .automatic) {
            Menu {
                Button("Select File...") { showFilePicker = true }
                let recent = viewModel.recentFiles.filter { $0 != viewModel.filePath }
                if !recent.isEmpty {
                    Divider()
                    ForEach(recent, id: \.self) { path in
                        Button((path as NSString).lastPathComponent) {
                            viewModel.selectFile(url: URL(fileURLWithPath: path))
                        }
                    }
                }
            } label: {
                Label("Change File", systemImage: "folder")
            }
            .help("Select a different alias file")
        }
    }
}
