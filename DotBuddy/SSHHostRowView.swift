import AppKit
import SwiftUI

struct SSHHostRowView: View {
    let host: SSHHost
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleEnabled: () -> Void
    var onDuplicate: (() -> Void)?

    @State private var isRowHovered = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(host.hostPattern)
                        .font(.subheadline.bold())

                    if !host.identityFile.isEmpty {
                        Text("key")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.orange.opacity(0.12), in: Capsule())
                    }
                }

                Text(host.summary)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .opacity(host.isEnabled ? 1 : 0.5)

            Spacer()

            HoverButton(
                icon: host.isEnabled ? "checkmark.circle.fill" : "circle",
                hoverColor: host.isEnabled ? .green : .secondary,
                action: onToggleEnabled,
                help: host.isEnabled ? "Disable host" : "Enable host"
            )

            if isRowHovered {
                HoverButton(icon: "doc.on.doc", hoverColor: .accentColor, action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("ssh \(host.hostPattern)", forType: .string)
                }, help: "Copy SSH command")

                if let onDuplicate {
                    HoverButton(icon: "plus.square.on.square", hoverColor: .accentColor, action: onDuplicate, help: "Duplicate host")
                }

                HoverButton(icon: "pencil", hoverColor: .accentColor, action: onEdit, help: "Edit host")

                HoverButton(icon: "trash", hoverColor: .red, action: onDelete, help: "Delete")
            }
        }
        .padding(.vertical, 2)
        .onHover { isRowHovered = $0 }
    }
}
