import SwiftUI

struct AliasFormView: View {
    @Binding var aliasName: String
    @Binding var aliasCommand: String
    @Binding var aliasGroup: String
    let existingGroups: [String]
    let isEditing: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @FocusState private var focusedField: FormField?
    @State private var isCreatingNewGroup = false
    private static let newGroupTag = "\u{0}__new_group__"

    private enum FormField {
        case name, command, group
    }

    var body: some View {
        HStack(spacing: 12) {
            TextField("Alias name", text: $aliasName)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .name)
                .onSubmit { focusedField = .command }
                .frame(minWidth: 120, maxWidth: 180)

            TextField("Command", text: $aliasCommand)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .command)
                .onSubmit { focusedField = .group }

            groupPicker
                .frame(minWidth: 140, maxWidth: 180)

            Button(isEditing ? "Update" : "Add", action: onSubmit)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(aliasName.isEmpty || aliasCommand.isEmpty)

            Button("Cancel", action: onCancel)
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onAppear { focusedField = .name }
    }

    @ViewBuilder
    private var groupPicker: some View {
        if existingGroups.isEmpty || isCreatingNewGroup {
            HStack(spacing: 4) {
                TextField("Group (optional)", text: $aliasGroup)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .group)
                    .onSubmit(onSubmit)

                if !existingGroups.isEmpty {
                    Button(action: {
                        isCreatingNewGroup = false
                        aliasGroup = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
        } else {
            Picker("Group", selection: $aliasGroup) {
                Text("No group").tag("")
                Divider()
                ForEach(existingGroups, id: \.self) { group in
                    Text(group).tag(group)
                }
                Divider()
                Text("New Group...").tag(Self.newGroupTag)
            }
            .labelsHidden()
            .onChange(of: aliasGroup) { _, newValue in
                if newValue == Self.newGroupTag {
                    aliasGroup = ""
                    isCreatingNewGroup = true
                    focusedField = .group
                }
            }
        }
    }
}
