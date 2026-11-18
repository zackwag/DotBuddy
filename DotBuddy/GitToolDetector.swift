import AppKit

struct GitEditorOption: Hashable, Identifiable {
    let name: String
    /// Shell command git runs as `core.editor`.
    let command: String
    var id: String { command }
}

struct GitDiffMergeTool: Hashable, Identifiable {
    let name: String
    let description: String
    var id: String { name }
}

enum GitToolDetector {
    private struct AppEditor {
        let name: String
        let bundleID: String
        /// Bundled CLI locations, relative to the .app; the first executable one wins. Unlisted if none exist.
        let cliPaths: [String]
        let waitFlag: String
    }

    private static let appEditors: [AppEditor] = [
        AppEditor(name: "Visual Studio Code", bundleID: "com.microsoft.VSCode",
                  cliPaths: ["Contents/Resources/app/bin/code"], waitFlag: "--wait"),
        AppEditor(name: "VS Code Insiders", bundleID: "com.microsoft.VSCodeInsiders",
                  cliPaths: ["Contents/Resources/app/bin/code-insiders", "Contents/Resources/app/bin/code"], waitFlag: "--wait"),
        AppEditor(name: "Cursor", bundleID: "com.todesktop.230313mzl4w4u92",
                  cliPaths: ["Contents/Resources/app/bin/cursor", "Contents/Resources/app/bin/code"], waitFlag: "--wait"),
        AppEditor(name: "VSCodium", bundleID: "com.vscodium",
                  cliPaths: ["Contents/Resources/app/bin/codium"], waitFlag: "--wait"),
        AppEditor(name: "Windsurf", bundleID: "com.exafunction.windsurf",
                  cliPaths: ["Contents/Resources/app/bin/windsurf"], waitFlag: "--wait"),
        AppEditor(name: "Zed", bundleID: "dev.zed.Zed", cliPaths: ["Contents/MacOS/cli"], waitFlag: "--wait"),
        AppEditor(name: "Zed Preview", bundleID: "dev.zed.Zed-Preview", cliPaths: ["Contents/MacOS/cli"], waitFlag: "--wait"),
        AppEditor(name: "Sublime Text", bundleID: "com.sublimetext.4",
                  cliPaths: ["Contents/SharedSupport/bin/subl"], waitFlag: "--wait"),
        AppEditor(name: "TextMate", bundleID: "com.macromates.TextMate",
                  cliPaths: ["Contents/MacOS/mate", "Contents/Resources/mate"], waitFlag: "-w"),
        AppEditor(name: "BBEdit", bundleID: "com.barebones.bbedit",
                  cliPaths: ["Contents/Helpers/bbedit_tool"], waitFlag: "--wait --resume"),
    ]

    private static let terminalEditors = ["nvim", "vim", "nano", "emacs", "hx", "micro"]

    // MARK: - Detection (slow: spawns a login shell, call off the main thread)

    static func installedEditors() -> [GitEditorOption] {
        let apps = appEditors.compactMap { editor -> GitEditorOption? in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: editor.bundleID) else {
                return nil
            }
            return option(for: editor, appURL: url)
        }
        let script = "for t in \(terminalEditors.joined(separator: " ")); do command -v $t >/dev/null && echo $t; done"
        let found = Set(runLoginShell(script).split(separator: "\n").map(String.init))
        let terminal = terminalEditors.filter(found.contains).map { GitEditorOption(name: $0, command: $0) }
        return apps + terminal
    }

    /// Asks git itself which of its built-in tools are installed, e.g. `vscode`, `opendiff`, `smerge`, `bc`.
    static func availableTools(_ command: String) -> [GitDiffMergeTool] {
        parseToolHelp(runLoginShell("git \(command) --tool-help"))
    }

    /// `core.editor` command for an app or executable picked in a file browser.
    static func editorCommand(forFileAt url: URL) -> String {
        guard url.pathExtension == "app" else {
            return shellQuoted(url.path)
        }
        if let bundleID = Bundle(url: url)?.bundleIdentifier,
           let editor = appEditors.first(where: { $0.bundleID == bundleID }),
           let option = option(for: editor, appURL: url) {
            return option.command
        }
        // Unknown app: -n starts a fresh instance so -W returns when that window's app quits, not every window.
        return "open -W -n -a \(shellQuoted(url.path))"
    }

    // MARK: - Pure helpers

    static func parseToolHelp(_ output: String) -> [GitDiffMergeTool] {
        var tools: [GitDiffMergeTool] = []
        var inAvailable = false
        for line in output.components(separatedBy: "\n") {
            if line.contains("may be set to one of the following") {
                inAvailable = true
                continue
            }
            guard inAvailable else {
                continue
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("The following") {
                break
            }
            let parts = trimmed.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard let name = parts.first else {
                continue
            }
            let description = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            tools.append(GitDiffMergeTool(name: String(name), description: description))
        }
        return tools
    }

    static func shellQuoted(_ value: String) -> String {
        guard value.contains(where: { " '\"$\\`!&;|<>()*?[]#~{}".contains($0) }) else {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }

    private static func option(for editor: AppEditor, appURL: URL) -> GitEditorOption? {
        let candidates = editor.cliPaths.map { appURL.appendingPathComponent($0).path }
        guard let cli = candidates.first(where: FileManager.default.isExecutableFile) else {
            return nil
        }
        return GitEditorOption(name: editor.name, command: "\(shellQuoted(cli)) \(editor.waitFlag)")
    }

    /// GUI apps get a minimal PATH; a login zsh picks up Homebrew etc. so results match what git sees in Terminal.
    /// shortcut: only `.zprofile`/`.zlogin` PATH changes are seen (not `.zshrc`), upgrade to `-i` if users report misses.
    private static func runLoginShell(_ script: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", script]
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(bytes: data, encoding: .utf8) ?? ""
    }
}
