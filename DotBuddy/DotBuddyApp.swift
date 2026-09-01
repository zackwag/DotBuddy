import AppKit
import SwiftUI

@main
struct DotBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var aliasViewModel = AliasViewModel()
    @StateObject private var envViewModel = EnvViewModel()
    @StateObject private var libraryStore = LibraryStore()
    @State private var activeSection: AppSection?
    @State private var menuBarSearch = ""

    var body: some Scene {
        Window("DotBuddy", id: "main") {
            Group {
                if let section = activeSection {
                    switch section {
                    case .aliases:
                        ContentView(viewModel: aliasViewModel, libraryStore: libraryStore, onBack: { activeSection = nil })
                    case .environment:
                        EnvContentView(viewModel: envViewModel, libraryStore: libraryStore, onBack: { activeSection = nil })
                    case .library:
                        LibraryView(
                            aliasViewModel: aliasViewModel,
                            envViewModel: envViewModel,
                            libraryStore: libraryStore,
                            onBack: { activeSection = nil }
                        )
                    }
                } else {
                    HomeView(
                        aliasViewModel: aliasViewModel,
                        envViewModel: envViewModel,
                        activeSection: $activeSection
                    )
                }
            }
            .frame(minWidth: 500, idealWidth: 700, minHeight: 300, idealHeight: 600)
            .onAppear {
                AppDelegate.shared = appDelegate
                appDelegate.aliasViewModel = aliasViewModel
                appDelegate.envViewModel = envViewModel
                aliasViewModel.loadAliases()
                envViewModel.loadVariables()
                libraryStore.load()
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .windowResizability(.contentSize)
        .defaultSize(width: 700, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra("DotBuddy", systemImage: "terminal.fill") {
            menuBarContent
                .frame(width: 320)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarContent: some View {
        VStack(spacing: 0) {
            TextField("Search...", text: $menuBarSearch)
                .textFieldStyle(.roundedBorder)
                .padding(8)

            let query = menuBarSearch.lowercased()
            let aliases = aliasViewModel.workingAliases.filter { alias in
                query.isEmpty || alias.name.lowercased().contains(query) || alias.command.lowercased().contains(query)
            }
            let variables = envViewModel.workingVariables.filter { v in
                query.isEmpty || v.name.lowercased().contains(query) || v.value.lowercased().contains(query)
            }

            if aliases.isEmpty && variables.isEmpty {
                Text("No matches")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !aliases.isEmpty {
                            menuBarAliasSection(aliases: Array(aliases.prefix(10)))
                        }

                        if !variables.isEmpty {
                            menuBarEnvSection(variables: Array(variables.prefix(10)))
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            Divider()

            HStack {
                Button("Open DotBuddy") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
            .padding(8)
        }
    }

    private func menuBarAliasSection(aliases: [Alias]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Aliases")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 2)
            ForEach(aliases) { alias in
                HStack(spacing: 6) {
                    Button {
                        aliasViewModel.toggleEnabled(alias)
                    } label: {
                        Image(systemName: alias.isEnabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(alias.isEnabled ? .green : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(alias.isEnabled ? "Disable" : "Enable")

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(alias.command, forType: .string)
                    } label: {
                        HStack {
                            Text(alias.name)
                                .font(.system(.body, design: .monospaced).bold())
                                .opacity(alias.isEnabled ? 1 : 0.5)
                            Spacer()
                            Text(alias.command)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
    }

    private func menuBarEnvSection(variables: [EnvVariable]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Variables")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 2)
            ForEach(variables) { variable in
                HStack(spacing: 6) {
                    Button {
                        envViewModel.toggleEnabled(variable)
                    } label: {
                        Image(systemName: variable.isEnabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(variable.isEnabled ? .green : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(variable.isEnabled ? "Disable" : "Enable")

                    Button {
                        if !variable.isSecret {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(variable.value, forType: .string)
                        }
                    } label: {
                        HStack {
                            Text(variable.name)
                                .font(.system(.body, design: .monospaced).bold())
                                .opacity(variable.isEnabled ? 1 : 0.5)
                            Spacer()
                            Text(variable.isSecret ? "••••••" : variable.value)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(variable.isSecret ? "Secret — open app to copy" : "Click to copy")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
    }

}

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    var aliasViewModel: AliasViewModel?
    var envViewModel: EnvViewModel?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let aliasUnsaved = aliasViewModel?.hasUnsavedChanges ?? false
        let envUnsaved = envViewModel?.hasUnsavedChanges ?? false

        guard aliasUnsaved || envUnsaved else {
            return .terminateNow
        }

        let alert = NSAlert()
        alert.messageText = "You have unsaved changes"
        alert.informativeText = "Do you want to save your changes before quitting?"
        alert.addButton(withTitle: "Save & Quit")
        alert.addButton(withTitle: "Quit Without Saving")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            if aliasUnsaved { aliasViewModel?.saveChanges() }
            if envUnsaved { envViewModel?.saveChanges() }
            return .terminateNow
        case .alertSecondButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }
}
