import SwiftUI

struct SSHHostFormView: View {
    @Binding var hostPattern: String
    @Binding var hostname: String
    @Binding var user: String
    @Binding var port: String
    @Binding var identityFile: String
    @Binding var group: String
    let existingGroups: [String]
    let isEditing: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @FocusState private var focusedField: FormField?
    @State private var isCreatingNewGroup = false
    private static let newGroupTag = "\u{0}__new_group__"

    private enum FormField {
        case pattern, hostname, user, port, identity, group
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                TextField("Host pattern", text: $hostPattern)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .pattern)
                    .onSubmit { focusedField = .hostname }
                    .frame(minWidth: 100, maxWidth: 150)

                TextField("HostName", text: $hostname)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .hostname)
                    .onSubmit { focusedField = .user }

                TextField("User", text: $user)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .user)
                    .onSubmit { focusedField = .port }
                    .frame(minWidth: 80, maxWidth: 120)

                TextField("Port", text: $port)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .port)
                    .onSubmit { focusedField = .identity }
                    .frame(minWidth: 50, maxWidth: 70)
            }

            HStack(spacing: 12) {
                TextField("IdentityFile (e.g. ~/.ssh/id_rsa)", text: $identityFile)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .identity)

                groupPicker
                    .frame(minWidth: 140, maxWidth: 180)

                Button(isEditing ? "Update" : "Add", action: onSubmit)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(hostPattern.isEmpty)

                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onAppear { focusedField = .pattern }
    }

    @ViewBuilder
    private var groupPicker: some View {
        if existingGroups.isEmpty || isCreatingNewGroup {
            HStack(spacing: 4) {
                TextField("Group (optional)", text: $group)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .group)
                    .onSubmit(onSubmit)

                if !existingGroups.isEmpty {
                    Button(action: {
                        isCreatingNewGroup = false
                        group = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
        } else {
            Picker("Group", selection: $group) {
                Text("No group").tag("")
                Divider()
                ForEach(existingGroups, id: \.self) { g in
                    Text(g).tag(g)
                }
                Divider()
                Text("New Group...").tag(Self.newGroupTag)
            }
            .labelsHidden()
            .onChange(of: group) { _, newValue in
                if newValue == Self.newGroupTag {
                    group = ""
                    isCreatingNewGroup = true
                    focusedField = .group
                }
            }
        }
    }
}
