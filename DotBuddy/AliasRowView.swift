import AppKit
import SwiftUI

struct AliasRowView: View {
    let alias: Alias
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleEnabled: () -> Void
    var onDuplicate: (() -> Void)?
    var dependencies: [String] = []

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(alias.name)
                        .font(.subheadline.bold())
                    if !dependencies.isEmpty {
                        Text("uses \(dependencies.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                Text(alias.command)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .opacity(alias.isEnabled ? 1 : 0.5)

            Spacer()

            HoverButton(
                icon: alias.isEnabled ? "checkmark.circle.fill" : "circle",
                hoverColor: alias.isEnabled ? .green : .secondary,
                action: onToggleEnabled,
                help: alias.isEnabled ? "Disable alias" : "Enable alias"
            )

            HoverButton(icon: "doc.on.doc", hoverColor: .accentColor, action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(alias.command, forType: .string)
            }, help: "Copy command")

            if let onDuplicate {
                HoverButton(icon: "plus.square.on.square", hoverColor: .accentColor, action: onDuplicate, help: "Duplicate alias")
            }

            HoverButton(icon: "pencil", hoverColor: .accentColor, action: onEdit, help: "Edit alias")

            HoverButton(icon: "trash", hoverColor: .red, action: onDelete, help: "Delete")
        }
        .padding(.vertical, 2)
    }
}
