import SwiftUI

struct SSHKeyGeneratorView: View {
    @ObservedObject var sshViewModel: SSHViewModel
    let onDismiss: () -> Void

    @State private var keyType: KeyType = .ed25519
    @State private var keyName = "id_ed25519"
    @State private var comment = ""
    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    @State private var bits = "4096"
    @State private var createHostEntry = false
    @State private var hostPattern = ""
    @State private var hostHostname = ""
    @State private var hostUser = ""
    @State private var hostGroup = ""
    @State private var isGenerating = false
    @State private var resultMessage: String?
    @State private var resultIsError = false
    @State private var generatedKeyPath: String?

    enum KeyGenResult {
        case success(String)
        case failure(String)
    }

    enum KeyType: String, CaseIterable {
        case ed25519
        case rsa
        case ecdsa

        var displayName: String {
            switch self {
            case .ed25519: return "Ed25519 (recommended)"
            case .rsa: return "RSA"
            case .ecdsa: return "ECDSA"
            }
        }

        var defaultFileName: String {
            "id_\(rawValue)"
        }

        var supportsBits: Bool {
            self == .rsa
        }
    }

    private var sshDir: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh").path
    }

    private var outputPath: String {
        (sshDir as NSString).appendingPathComponent(keyName)
    }

    private var keyExists: Bool {
        FileManager.default.fileExists(atPath: outputPath)
    }

    private var passphrasesMismatch: Bool {
        !passphrase.isEmpty && passphrase != confirmPassphrase
    }

    private var canGenerate: Bool {
        !keyName.isEmpty && !isGenerating && !passphrasesMismatch && !keyExists
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    keyTypeSection
                    fileSection
                    authSection
                    if sshViewModel.hasFile {
                        hostEntrySection
                    }
                    resultSection
                }
                .padding()
            }
            Divider()
            footer
        }
        .frame(width: 520, height: 520)
        .onChange(of: keyType) { _, newType in
            if keyName == KeyType.ed25519.defaultFileName ||
               keyName == KeyType.rsa.defaultFileName ||
               keyName == KeyType.ecdsa.defaultFileName {
                keyName = newType.defaultFileName
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "key.fill")
                .font(.title2)
                .foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 2) {
                Text("Generate SSH Key")
                    .font(.headline)
                Text("Create a new SSH key pair")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    private var keyTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Key Type")
                .font(.subheadline.bold())

            Picker("Algorithm", selection: $keyType) {
                ForEach(KeyType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            if keyType.supportsBits {
                HStack {
                    Text("Bits:")
                        .font(.callout)
                    Picker("Bits", selection: $bits) {
                        Text("2048").tag("2048")
                        Text("4096").tag("4096")
                    }
                    .labelsHidden()
                    .frame(width: 100)
                }
            }
        }
    }

    private var fileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("File")
                .font(.subheadline.bold())

            HStack {
                Text("~/.ssh/")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                TextField("Key name", text: $keyName)
                    .textFieldStyle(.roundedBorder)
            }

            if keyExists {
                Label("A key with this name already exists", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Text("Comment (optional)")
                .font(.callout)
            TextField("e.g. your@email.com", text: $comment)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var authSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Passphrase")
                .font(.subheadline.bold())

            SecureField("Passphrase (optional but recommended)", text: $passphrase)
                .textFieldStyle(.roundedBorder)

            if !passphrase.isEmpty {
                SecureField("Confirm passphrase", text: $confirmPassphrase)
                    .textFieldStyle(.roundedBorder)

                if passphrasesMismatch {
                    Label("Passphrases do not match", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var hostEntrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Add SSH config entry for this key", isOn: $createHostEntry)
                .font(.subheadline.bold())

            if createHostEntry {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Host pattern")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. myserver", text: $hostPattern)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("HostName")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. 192.168.1.1", text: $hostHostname)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("User")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. deploy", text: $hostUser)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                if !sshViewModel.groups.isEmpty {
                    Picker("Group", selection: $hostGroup) {
                        Text("No group").tag("")
                        ForEach(sshViewModel.groups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    .frame(maxWidth: 200)
                }
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if let resultMessage {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: resultIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(resultIsError ? .red : .green)
                VStack(alignment: .leading, spacing: 4) {
                    Text(resultMessage)
                        .font(.callout)
                    if let path = generatedKeyPath, !resultIsError {
                        Text(path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(resultIsError ? .red.opacity(0.08) : .green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var footer: some View {
        HStack {
            if let path = generatedKeyPath, !resultIsError {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                }
                .controlSize(.small)

                Button("Copy Public Key") {
                    if let pubKey = try? String(contentsOfFile: path + ".pub", encoding: .utf8) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(pubKey.trimmingCharacters(in: .whitespacesAndNewlines), forType: .string)
                    }
                }
                .controlSize(.small)
            }

            Spacer()

            Button("Close", action: onDismiss)
                .keyboardShortcut(.escape, modifiers: [])

            Button("Generate") { generateKey() }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(!canGenerate)
        }
        .padding()
    }

    struct KeyGenConfig: Sendable {
        let type: KeyType
        let outputPath: String
        let passphrase: String
        let comment: String
        let bits: String
    }

    private func generateKey() {
        isGenerating = true
        resultMessage = nil
        generatedKeyPath = nil

        let config = KeyGenConfig(
            type: keyType, outputPath: outputPath,
            passphrase: passphrase, comment: comment, bits: bits
        )
        let dir = sshDir

        Task.detached {
            let result = Self.runKeyGen(config: config, sshDir: dir)

            await MainActor.run { [self] in
                isGenerating = false

                switch result {
                case .success(let path):
                    generatedKeyPath = path
                    resultMessage = "Key pair generated successfully."
                    resultIsError = false

                    if createHostEntry && !hostPattern.isEmpty {
                        sshViewModel.addHost(SSHHost(
                            hostPattern: hostPattern,
                            hostname: hostHostname,
                            user: hostUser,
                            identityFile: "~/.ssh/\(keyName)",
                            group: hostGroup
                        ))
                    }

                case .failure(let error):
                    resultMessage = error
                    resultIsError = true
                }
            }
        }
    }

    private nonisolated static func runKeyGen(config: KeyGenConfig, sshDir: String) -> KeyGenResult {
        if !FileManager.default.fileExists(atPath: sshDir) {
            do {
                try FileManager.default.createDirectory(atPath: sshDir, withIntermediateDirectories: true)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: sshDir)
            } catch {
                return .failure("Failed to create ~/.ssh directory: \(error.localizedDescription)")
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")

        var args = ["-t", config.type.rawValue, "-f", config.outputPath, "-N", config.passphrase]
        if !config.comment.isEmpty {
            args += ["-C", config.comment]
        }
        if config.type.supportsBits {
            args += ["-b", config.bits]
        }

        process.arguments = args
        let errorPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failure("Failed to run ssh-keygen: \(error.localizedDescription)")
        }

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorStr = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
            return .failure("ssh-keygen failed: \(errorStr)")
        }

        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: config.outputPath)
        } catch {}

        return .success(config.outputPath)
    }
}
