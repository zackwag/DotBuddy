import ServiceManagement
import SwiftUI

enum TerminalApp: String, CaseIterable, Identifiable {
    case terminal = "Terminal"
    case iterm = "iTerm2"
    case warp = "Warp"

    var id: String { rawValue }

    func launchSSH(host: String) {
        let escaped = host.replacingOccurrences(of: "\"", with: "\\\"")
        let script: String
        switch self {
        case .terminal:
            script = "tell application \"Terminal\" to do script \"ssh \(escaped)\""
        case .iterm:
            script = "tell application \"iTerm2\" to create window with default profile command \"ssh \(escaped)\""
        case .warp:
            script = "tell application \"Warp\" to do script \"ssh \(escaped)\""
        }
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.open(url)
        }
    }

    private var bundleID: String {
        switch self {
        case .terminal: return "com.apple.Terminal"
        case .iterm: return "com.googlecode.iterm2"
        case .warp: return "dev.warp.Warp-Stable"
        }
    }
}

struct SettingsView: View {
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @AppStorage("preferredTerminal") private var preferredTerminal = TerminalApp.terminal.rawValue
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show menu bar icon", isOn: $showMenuBarExtra)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Picker("Terminal app", selection: $preferredTerminal) {
                    ForEach(TerminalApp.allCases) { app in
                        Text(app.rawValue).tag(app.rawValue)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360, height: 180)
    }
}
