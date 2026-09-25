import AppKit
import SwiftUI

struct KnownHostRowView: View {
    let host: KnownHost
    let onDelete: () -> Void
    var onDuplicate: (() -> Void)?

    @State private var isRowHovered = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(host.displayName)
                        .font(.subheadline.bold())

                    Text(host.keyType)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.teal)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.teal.opacity(0.12), in: Capsule())

                    if host.isHashed {
                        Text("hashed")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.purple.opacity(0.12), in: Capsule())
                    }
                }

                Text(host.truncatedKey)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isRowHovered {
                HoverButton(icon: "doc.on.doc", hoverColor: .accentColor, action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(host.publicKey, forType: .string)
                }, help: "Copy public key")

                if let onDuplicate {
                    HoverButton(icon: "plus.square.on.square", hoverColor: .accentColor, action: onDuplicate, help: "Duplicate host")
                }

                HoverButton(icon: "trash", hoverColor: .red, action: onDelete, help: "Remove host")
            }
        }
        .padding(.vertical, 2)
        .onHover { isRowHovered = $0 }
    }
}
