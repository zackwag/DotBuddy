import AppKit
import LocalAuthentication
import SwiftUI

struct EnvRowView: View {
    let variable: EnvVariable
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleSecret: () -> Void

    @State private var isRevealed = false
    @State private var authError: String?
    @State private var showAuthError = false

    private var inferredType: ValueType {
        ValueType.infer(from: variable.value, name: variable.name)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(variable.name)
                        .font(.subheadline.bold())

                    Text(inferredType.label)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(inferredType.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(inferredType.color.opacity(0.12), in: Capsule())
                }

                if variable.isSecret && !isRevealed {
                    Text(String(repeating: "\u{2022}", count: 12))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(inferredType.displayValue(variable.value))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if variable.isSecret {
                HoverButton(
                    icon: isRevealed ? "eye.slash" : "eye",
                    hoverColor: .accentColor,
                    action: {
                        if isRevealed { isRevealed = false } else { authenticate() }
                    },
                    help: isRevealed ? "Hide value" : "Reveal value (Touch ID)"
                )
            }

            HoverButton(icon: "doc.on.doc", hoverColor: .accentColor, action: copyValue, help: "Copy value")

            HoverButton(
                icon: variable.isSecret ? "lock.fill" : "lock.open",
                hoverColor: .orange,
                action: onToggleSecret,
                help: variable.isSecret ? "Mark as visible" : "Mark as secret"
            )

            HoverButton(icon: "pencil", hoverColor: .accentColor, action: onEdit, help: "Edit variable")

            DeleteButton(action: onDelete)
        }
        .padding(.vertical, 2)
        .alert("Authentication Failed", isPresented: $showAuthError) {
            Button("OK") {}
        } message: {
            Text(authError ?? "Could not verify your identity.")
        }
    }

    private func copyValue() {
        if variable.isSecret {
            authenticateWithBiometrics(reason: "Copy secret value") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(variable.value, forType: .string)
            }
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(variable.value, forType: .string)
        }
    }

    private func authenticate() {
        authenticateWithBiometrics(reason: "Reveal secret value") {
            isRevealed = true
        }
    }

    private func authenticateWithBiometrics(reason: String, onSuccess: @escaping () -> Void) {
        let context = LAContext()
        var error: NSError?

        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication

        context.evaluatePolicy(policy, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    onSuccess()
                } else if let error {
                    authError = error.localizedDescription
                    showAuthError = true
                }
            }
        }
    }
}

enum ValueType {
    case boolean
    case integer
    case path
    case pathList
    case url
    case email
    case arn
    case uuid
    case password
    case args
    case string

    var label: String {
        switch self {
        case .boolean: return "bool"
        case .integer: return "int"
        case .path: return "path"
        case .pathList: return "paths"
        case .url: return "url"
        case .email: return "email"
        case .arn: return "arn"
        case .uuid: return "uuid"
        case .password: return "secret"
        case .args: return "args"
        case .string: return "string"
        }
    }

    var color: Color {
        switch self {
        case .boolean: return .purple
        case .integer: return .blue
        case .path: return .orange
        case .pathList: return .orange
        case .url: return .teal
        case .email: return .pink
        case .arn: return .yellow
        case .uuid: return .indigo
        case .password: return .red
        case .args: return .mint
        case .string: return .gray
        }
    }

    func displayValue(_ value: String) -> String {
        switch self {
        case .boolean:
            return (value == "1" || value.lowercased() == "true" || value.lowercased() == "yes") ? "true" : "false"
        default:
            return value
        }
    }

    private static let secretNameSegments: Set<String> = ["token", "secret", "password", "passwd", "key"]
    private static let secretNameExact: Set<String> = ["api_key", "apikey", "private_key"]

    static func infer(from value: String, name: String = "") -> ValueType {
        let lowerName = name.lowercased()
        let segments = Set(lowerName.split(separator: "_").map(String.init))
        if !segments.isDisjoint(with: secretNameSegments) || secretNameExact.contains(where: { lowerName.contains($0) }) {
            return .password
        }

        let lower = value.lowercased()

        if lower == "0" || lower == "1" || lower == "true" || lower == "false" || lower == "yes" || lower == "no" {
            return .boolean
        }

        if Int(value) != nil && value.count > 1 {
            return .integer
        }

        if looksLikeUUID(value) {
            return .uuid
        }

        if value.hasPrefix("arn:") {
            return .arn
        }

        if looksLikeEmail(value) {
            return .email
        }

        if value.hasPrefix("http://") || value.hasPrefix("https://") {
            return .url
        }

        if value.hasPrefix("-") || value.hasPrefix("--") {
            return .args
        }

        if value.contains(":") && value.contains("/") && !value.contains(" ") && value.filter({ $0 == ":" }).count >= 2 {
            return .pathList
        }

        if value.hasPrefix("/") || value.hasPrefix("~/") || value.hasPrefix("$HOME") || value.hasPrefix("$") {
            return .path
        }

        return .string
    }

    private static func looksLikeEmail(_ value: String) -> Bool {
        guard value.contains("@") && !value.contains(" ") else { return false }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return false }
        let range = NSRange(value.startIndex..., in: value)
        guard let match = detector.firstMatch(in: value, range: range) else { return false }
        return match.url?.scheme == "mailto" && match.range.length == value.count
    }

    private static func looksLikeUUID(_ value: String) -> Bool {
        let parts = value.split(separator: "-")
        guard parts.count == 5 else { return false }
        let expectedLengths = [8, 4, 4, 4, 12]
        for (part, length) in zip(parts, expectedLengths) {
            guard part.count == length && part.allSatisfy({ $0.isHexDigit }) else { return false }
        }
        return true
    }

}
