import SwiftUI

struct HoverButton: View {
    let icon: String
    let hoverColor: Color
    let action: () -> Void
    var help: String = ""

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundStyle(isHovered ? hoverColor : .secondary)
        }
        .buttonStyle(.borderless)
        .help(help)
        .onHover { isHovered = $0 }
    }
}

struct DeleteButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .foregroundStyle(isHovered ? .red : .secondary)
        }
        .buttonStyle(.borderless)
        .help("Delete")
        .onHover { isHovered = $0 }
    }
}
