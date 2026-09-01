import SwiftUI

struct ItemFormView: View {
    @Binding var itemName: String
    @Binding var itemValue: String
    @Binding var itemGroup: String
    let existingGroups: [String]
    let isEditing: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void
    var nameLabel: String = "Name"
    var valueLabel: String = "Value"
    var shadowWarning: String?

    @FocusState private var focusedField: FormField?
    @State private var isCreatingNewGroup = false
    private static let newGroupTag = "\u{0}__new_group__"

    private enum FormField {
        case name, value, group
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                TextField(nameLabel, text: $itemName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .name)
                    .onSubmit { focusedField = .value }
                if let shadowWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .help(shadowWarning)
                }
            }
            .frame(minWidth: 120, maxWidth: 180)

            TextField(valueLabel, text: $itemValue)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .value)
                .onSubmit { focusedField = .group }

            groupPicker
                .frame(minWidth: 140, maxWidth: 180)

            Button(isEditing ? "Update" : "Add", action: onSubmit)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(itemName.isEmpty || itemValue.isEmpty)

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
                TextField("Group (optional)", text: $itemGroup)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .group)
                    .onSubmit(onSubmit)

                if !existingGroups.isEmpty {
                    Button(action: {
                        isCreatingNewGroup = false
                        itemGroup = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
        } else {
            Picker("Group", selection: $itemGroup) {
                Text("No group").tag("")
                Divider()
                ForEach(existingGroups, id: \.self) { group in
                    Text(group).tag(group)
                }
                Divider()
                Text("New Group...").tag(Self.newGroupTag)
            }
            .labelsHidden()
            .onChange(of: itemGroup) { _, newValue in
                if newValue == Self.newGroupTag {
                    itemGroup = ""
                    isCreatingNewGroup = true
                    focusedField = .group
                }
            }
        }
    }
}

typealias AliasFormView = ItemFormView
typealias EnvFormView = ItemFormView
