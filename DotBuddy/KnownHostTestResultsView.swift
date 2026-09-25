import SwiftUI

struct KnownHostTestResultsView: View {
    let results: [KnownHostTestResult]
    let skippedCount: Int
    let isTesting: Bool
    let onDismiss: () -> Void
    let onRemoveHosts: (Set<UUID>) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            resultsList
            Divider()
            footer
        }
        .frame(width: 440, height: 400)
    }

    private var header: some View {
        HStack {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.title2)
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text("Known Host Reachability")
                    .font(.headline)
                Text(isTesting ? "Testing connections..." : summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isTesting {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding()
    }

    private var summaryText: String {
        let passed = results.filter { $0.status == .success }.count
        let failed = results.filter { $0.status == .failure }.count
        var text = "\(passed) reachable, \(failed) unreachable of \(results.count) hosts"
        if skippedCount > 0 {
            text += " (\(skippedCount) hashed skipped)"
        }
        return text
    }

    private var resultsList: some View {
        List {
            ForEach(results) { result in
                HStack {
                    resultIcon(for: result.status)

                    Text(result.hostname)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)

                    Spacer()

                    resultLabel(for: result.status)

                    if result.status == .failure {
                        Button {
                            onRemoveHosts(Set([result.id]))
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .help("Remove this host")
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func resultIcon(for status: SSHConnectionStatus) -> some View {
        switch status {
        case .idle:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        case .testing:
            ProgressView()
                .controlSize(.mini)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func resultLabel(for status: SSHConnectionStatus) -> some View {
        switch status {
        case .idle:
            Text("Pending")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .testing:
            Text("Testing...")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .success:
            Text("Reachable")
                .font(.caption)
                .foregroundStyle(.green)
        case .failure:
            Text("Unreachable")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private var failedIDs: Set<UUID> {
        Set(results.filter { $0.status == .failure }.map(\.id))
    }

    private var footer: some View {
        HStack {
            if !isTesting && !failedIDs.isEmpty {
                Button("Remove All Unreachable") {
                    onRemoveHosts(failedIDs)
                }
                .foregroundStyle(.red)
            }
            Spacer()
            Button("Close", action: onDismiss)
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding()
    }
}
