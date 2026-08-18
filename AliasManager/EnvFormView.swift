import SwiftUI

struct EnvFormView: View {
    @Binding var varName: String
    @Binding var varValue: String
    @Binding var varGroup: String
    let existingGroups: [String]
    let isEditing: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @FocusState private var focusedField: FormField?
    @State private var isCreatingNewGroup = false
    private static let newGroupTag = "\u{0}__new_group__"

    private enum FormField {
        case name, value, group
    }

    var body: some View {
        HStack(spacing: 12) {
            TextField("Variable name", text: $varName)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .name)
                .onSubmit { focusedField = .value }
                .frame(minWidth: 120, maxWidth: 180)

            TextField("Value", text: $varValue)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .value)
                .onSubmit { focusedField = .group }

            groupPicker
                .frame(minWidth: 140, maxWidth: 180)

            Button(isEditing ? "Update" : "Add", action: onSubmit)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(varName.isEmpty || varValue.isEmpty)

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
                TextField("Group (optional)", text: $varGroup)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .group)
                    .onSubmit(onSubmit)

                if !existingGroups.isEmpty {
                    Button(action: {
                        isCreatingNewGroup = false
                        varGroup = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
        } else {
            Picker("Group", selection: $varGroup) {
                Text("No group").tag("")
                Divider()
                ForEach(existingGroups, id: \.self) { group in
                    Text(group).tag(group)
                }
                Divider()
                Text("New Group...").tag(Self.newGroupTag)
            }
            .labelsHidden()
            .onChange(of: varGroup) { _, newValue in
                if newValue == Self.newGroupTag {
                    varGroup = ""
                    isCreatingNewGroup = true
                    focusedField = .group
                }
            }
        }
    }
}
