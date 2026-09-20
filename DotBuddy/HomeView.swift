import SwiftUI

enum AppSection: Hashable {
    case aliases
    case environment
    case sshConfig
    case knownHosts
    case library
}

struct HomeView: View {
    @ObservedObject var aliasViewModel: AliasViewModel
    @ObservedObject var envViewModel: EnvViewModel
    @ObservedObject var sshViewModel: SSHViewModel
    @ObservedObject var knownHostsViewModel: KnownHostsViewModel
    @Binding var activeSection: AppSection?
    @StateObject private var historyInsights = HistoryInsights()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)

                VStack(spacing: 4) {
                    Text("DotBuddy")
                        .font(.largeTitle.bold())

                    Text("Manage your shell configuration")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    aliasCard
                    envCard
                }
                .padding(.top, 12)

                HStack(alignment: .top, spacing: 16) {
                    sshConfigCard
                    knownHostsCard
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

                libraryCard
                    .padding(.top, 4)

                if !historyInsights.suggestions.isEmpty {
                    insightsCard
                        .padding(.top, 4)
                }
            }

            Spacer()

            footer
        }
        .frame(maxWidth: .infinity)
        .padding()
        .onAppear {
            let existing = Dictionary(
                aliasViewModel.workingAliases.map { ($0.name, $0.command) },
                uniquingKeysWith: { first, _ in first }
            )
            historyInsights.analyze(existingAliases: existing)
        }
    }

    private var aliasCard: some View {
        Button(action: { activeSection = .aliases }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "terminal")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    Spacer()
                    Text("\(aliasViewModel.aliases.count)")
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                }

                Text("Aliases")
                    .font(.headline)

                if aliasViewModel.hasFile {
                    Text(aliasFileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    groupList(for: aliasViewModel.groups, limit: 4)
                } else {
                    Text("Not configured")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .frame(minWidth: 180, maxWidth: 240, alignment: .leading)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
        }
        .buttonStyle(CardButtonStyle())
    }

    private var envCard: some View {
        Button(action: { activeSection = .environment }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Spacer()
                    Text("\(envViewModel.variables.count)")
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                }

                Text("Environment")
                    .font(.headline)

                if envViewModel.hasFile {
                    Text(envFileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    groupList(for: envViewModel.groups, limit: 4)
                } else {
                    Text("Not configured")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .frame(minWidth: 180, maxWidth: 240, alignment: .leading)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
        }
        .buttonStyle(CardButtonStyle())
    }

    private var sshConfigCard: some View {
        Button(action: { activeSection = .sshConfig }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "lock.shield")
                        .font(.title2)
                        .foregroundStyle(.teal)
                    Spacer()
                    Text("\(sshViewModel.hosts.count)")
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                }

                Text("SSH Config")
                    .font(.headline)

                if sshViewModel.hasFile {
                    Text(sshConfigFileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    groupList(for: sshViewModel.groups, limit: 4)
                } else {
                    Text("Not configured")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .frame(minWidth: 180, maxWidth: 240, maxHeight: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
        }
        .buttonStyle(CardButtonStyle())
    }

    private var knownHostsCard: some View {
        Button(action: { activeSection = .knownHosts }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "key.viewfinder")
                        .font(.title2)
                        .foregroundStyle(.indigo)
                    Spacer()
                    Text("\(knownHostsViewModel.hosts.count)")
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                }

                Text("Known Hosts")
                    .font(.headline)

                if knownHostsViewModel.hasFile {
                    Text(knownHostsFileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    let hashedCount = knownHostsViewModel.hosts.filter(\.isHashed).count
                    let keyTypes = Set(knownHostsViewModel.hosts.map(\.keyType))
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(keyTypes.prefix(4)).sorted(), id: \.self) { keyType in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.secondary.opacity(0.4))
                                    .frame(width: 5, height: 5)
                                Text(keyType)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if hashedCount > 0 {
                            Text("\(hashedCount) hashed")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } else {
                    Text("Not configured")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .frame(minWidth: 180, maxWidth: 240, maxHeight: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
        }
        .buttonStyle(CardButtonStyle())
    }

    private var libraryCard: some View {
        Button(action: { activeSection = .library }) {
            HStack(spacing: 12) {
                Image(systemName: "book.closed")
                    .font(.title2)
                    .foregroundStyle(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Snippet Library")
                        .font(.headline)
                    Text("Browse commonly used aliases and environment variables")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: 496, alignment: .leading)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
        }
        .buttonStyle(CardButtonStyle())
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3)
                    .foregroundStyle(.orange)
                Text("Frequently Used Commands")
                    .font(.headline)
                Spacer()
            }

            Text("Commands you run often that could become aliases")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(historyInsights.suggestions.prefix(5)) { suggestion in
                HStack {
                    Text(suggestion.command)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                    Spacer()
                    Text("\(suggestion.count)x")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Button("Add as '\(suggestion.suggestedAlias)'") {
                        aliasViewModel.addAlias(
                            name: suggestion.suggestedAlias,
                            command: suggestion.command,
                            group: "From History"
                        )
                    }
                    .controlSize(.small)
                    .disabled(!aliasViewModel.hasFile)
                }
            }
        }
        .padding()
        .frame(maxWidth: 496, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
    }

    private var footer: some View {
        HStack {
            if let aliasPath = aliasViewModel.filePath {
                Label(aliasPath, systemImage: "doc.text")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            if let envPath = envViewModel.filePath {
                Label(envPath, systemImage: "doc.text")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var aliasFileName: String {
        guard let path = aliasViewModel.filePath else { return "" }
        return (path as NSString).lastPathComponent
    }

    private var envFileName: String {
        guard let path = envViewModel.filePath else { return "" }
        return (path as NSString).lastPathComponent
    }

    private var sshConfigFileName: String {
        guard let path = sshViewModel.filePath else { return "" }
        return (path as NSString).lastPathComponent
    }

    private var knownHostsFileName: String {
        guard let path = knownHostsViewModel.filePath else { return "" }
        return (path as NSString).lastPathComponent
    }

    private func groupList(for groups: [String], limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(groups.prefix(limit), id: \.self) { group in
                HStack(spacing: 4) {
                    Circle()
                        .fill(.secondary.opacity(0.4))
                        .frame(width: 5, height: 5)
                    Text(group)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if groups.count > limit {
                Text("+\(groups.count - limit) more")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct CardButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : isHovered ? 1.02 : 1.0)
            .shadow(color: .black.opacity(isHovered ? 0.1 : 0), radius: 8, y: 4)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}
