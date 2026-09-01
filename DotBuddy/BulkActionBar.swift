import SwiftUI

struct BulkActionBar: View {
    let selectedCount: Int
    let existingGroups: [String]
    let onEnable: () -> Void
    let onDisable: () -> Void
    let onDelete: () -> Void
    let onSetGroup: (String) -> Void
    let onCancel: () -> Void

    @State private var newGroupName = ""
    @State private var showNewGroupField = false

    var body: some View {
        HStack(spacing: 10) {
            Text("\(selectedCount) selected")
                .font(.callout.bold())
                .foregroundStyle(.secondary)

            Divider().frame(height: 16)

            Button(action: onEnable) {
                Label("Enable", systemImage: "checkmark.circle")
            }
            .controlSize(.small)

            Button(action: onDisable) {
                Label("Disable", systemImage: "circle")
            }
            .controlSize(.small)

            Menu {
                Button("No group") { onSetGroup("") }
                if !existingGroups.isEmpty {
                    Divider()
                    ForEach(existingGroups, id: \.self) { group in
                        Button(group) { onSetGroup(group) }
                    }
                }
                Divider()
                Button("New Group...") { showNewGroupField = true }
            } label: {
                Label("Move to Group", systemImage: "folder")
            }
            .controlSize(.small)

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .controlSize(.small)

            Spacer()

            Button("Done", action: onCancel)
                .controlSize(.small)
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
        .popover(isPresented: $showNewGroupField) {
            HStack(spacing: 8) {
                TextField("Group name", text: $newGroupName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .onSubmit {
                        let name = newGroupName.trimmingCharacters(in: .whitespaces)
                        if !name.isEmpty {
                            onSetGroup(name)
                            newGroupName = ""
                            showNewGroupField = false
                        }
                    }
                Button("Add") {
                    let name = newGroupName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        onSetGroup(name)
                        newGroupName = ""
                        showNewGroupField = false
                    }
                }
                .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
    }
}
