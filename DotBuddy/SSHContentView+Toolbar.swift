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
            Button(action: { viewModel.testAllConnections() }) {
                Label("Test All", systemImage: "antenna.radiowaves.left.and.right")
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .help("Test all enabled host connections (Cmd+Shift+T)")
            .disabled(
                !viewModel.hasFile ||
                viewModel.workingHosts.filter(\.isEnabled).isEmpty ||
                viewModel.isTestingAll
            )
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button(action: exportHosts) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.workingHosts.isEmpty)

                Button(action: { showImportPicker = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }

                Divider()

                Button(action: { showLibrary = true }) {
                    Label("Library", systemImage: "book")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .help("Export, import, or browse library")
            .disabled(!viewModel.hasFile)
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
