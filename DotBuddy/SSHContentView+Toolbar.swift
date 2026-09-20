import SwiftUI

extension SSHContentView {
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
                Label("Add Host", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .help("Add a new SSH host (Cmd+N)")
            .disabled(!viewModel.hasFile)
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: { showKeyGenerator = true }) {
                Label("Generate Key", systemImage: "key.fill")
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .help("Generate a new SSH key pair (Cmd+Shift+G)")
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: exportHosts) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .keyboardShortcut("e", modifiers: .command)
            .help("Export SSH config to a file (Cmd+E)")
            .disabled(!viewModel.hasFile || viewModel.workingHosts.isEmpty)
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
            .help("Select a different SSH config file")
        }
    }
}
