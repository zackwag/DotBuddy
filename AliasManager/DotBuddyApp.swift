import AppKit
import SwiftUI

@main
struct DotBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var aliasViewModel = AliasViewModel()
    @StateObject private var envViewModel = EnvViewModel()
    @State private var activeSection: AppSection?

    var body: some Scene {
        Window("DotBuddy", id: "main") {
            Group {
                if let section = activeSection {
                    switch section {
                    case .aliases:
                        ContentView(viewModel: aliasViewModel, onBack: { activeSection = nil })
                    case .environment:
                        EnvContentView(viewModel: envViewModel, onBack: { activeSection = nil })
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
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .windowResizability(.contentSize)
        .defaultSize(width: 700, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
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
