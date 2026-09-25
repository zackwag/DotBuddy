import SwiftUI

struct SettingsView: View {
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show menu bar icon", isOn: $showMenuBarExtra)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360, height: 120)
    }
}
