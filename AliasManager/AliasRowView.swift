import AppKit
import SwiftUI

struct AliasRowView: View {
    let alias: Alias
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(alias.name)
                    .font(.subheadline.bold())
                Text(alias.command)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HoverButton(icon: "doc.on.doc", hoverColor: .accentColor, action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(alias.command, forType: .string)
            }, help: "Copy command")

            HoverButton(icon: "pencil", hoverColor: .accentColor, action: onEdit, help: "Edit alias")

            DeleteButton(action: onDelete)
        }
        .padding(.vertical, 2)
    }
}
