import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class GitConfigViewModel: ObservableObject {
    @Published var entries: [GitConfigEntry] = []
    @Published var workingEntries: [GitConfigEntry] = [] {
        didSet { registerUndo(oldValue: oldValue) }
    }
    var undoManager: UndoManager?
    @Published var searchText: String = ""
    @Published var filePath: String?
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var fileChangedExternally = false
    private var fileWatcher: FileWatcher?
    private var suppressNextWatch = false

    private static let filePathKey = "gitConfigFilePath"

    var hasUnsavedChanges: Bool {
        entries != workingEntries
    }

    var hasFile: Bool {
        filePath != nil
    }

    var fileName: String {
        guard let filePath else { return "No file selected" }
        return (filePath as NSString).lastPathComponent
    }

    var sections: [String] {
        var seen = Set<String>()
        return workingEntries.map(\.section).filter { seen.insert($0).inserted }
    }

    /// Entries grouped by section in first-appearance order; file order is kept within a section.
    var displayedSections: [(section: String, entries: [GitConfigEntry])] {
        let query = searchText.lowercased()
        let filtered = query.isEmpty ? workingEntries : workingEntries.filter {
            $0.section.lowercased().contains(query) ||
            $0.key.lowercased().contains(query) ||
            $0.value.lowercased().contains(query)
        }
        let grouped = Dictionary(grouping: filtered, by: \.section)
        return sections.compactMap { section in
            grouped[section].map { (section, $0) }
        }
    }

    init() {
        filePath = UserDefaults.standard.string(forKey: Self.filePathKey)
    }

    func selectFile(url: URL) {
        filePath = url.path
        UserDefaults.standard.set(url.path, forKey: Self.filePathKey)
        loadEntries()
    }

    func useDefault() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let legacy = home.appendingPathComponent(".gitconfig").path
        let xdg = home.appendingPathComponent(".config/git/config").path
        // Git reads both; prefer ~/.gitconfig (where `git config --global` writes) unless only the XDG file exists.
        let path = !FileManager.default.fileExists(atPath: legacy) && FileManager.default.fileExists(atPath: xdg) ? xdg : legacy
        filePath = path
        UserDefaults.standard.set(path, forKey: Self.filePathKey)
        loadEntries()
    }

    func loadEntries() {
        guard let filePath else { return }
        do {
            entries = try GitConfigFileManager(path: filePath).load()
            workingEntries = entries
            startWatching(path: filePath)
        } catch {
            showError(message: "Failed to load git config: \(error.localizedDescription)")
        }
    }

    private func startWatching(path: String) {
        fileWatcher = FileWatcher { [weak self] in
            guard let self else { return }
            if self.suppressNextWatch {
                self.suppressNextWatch = false
                return
            }
            self.fileChangedExternally = true
            self.sendFileChangedNotification(fileName: self.fileName)
        }
        fileWatcher?.watch(path: path)
    }

    func reloadFromDisk() {
        fileChangedExternally = false
        loadEntries()
    }

    /// Adds a new entry (`id == nil`) or updates an existing one. An entry whose section changes moves to the end of
    /// its new section so it serializes under that header.
    func saveEntry(id: UUID?, section: String, key: String, value: String) {
        var updated = workingEntries
        if let id, let index = updated.firstIndex(where: { $0.id == id }) {
            if updated[index].section == section {
                updated[index] = GitConfigEntry(id: id, section: section, key: key, value: value)
                workingEntries = updated
                return
            }
            updated.remove(at: index)
        }
        let entry = GitConfigEntry(id: id ?? UUID(), section: section, key: key, value: value)
        if let last = updated.lastIndex(where: { $0.section == section }) {
            updated.insert(entry, at: last + 1)
        } else {
            updated.append(entry)
        }
        workingEntries = updated
    }

    func duplicateEntry(_ entry: GitConfigEntry) {
        let copy = GitConfigEntry(section: entry.section, key: entry.key, value: entry.value)
        if let index = workingEntries.firstIndex(where: { $0.id == entry.id }) {
            workingEntries.insert(copy, at: index + 1)
        } else {
            workingEntries.append(copy)
        }
    }

    func deleteEntry(_ entry: GitConfigEntry) {
        workingEntries.removeAll { $0.id == entry.id }
    }

    func saveChanges() {
        guard let filePath else { return }
        do {
            entries = workingEntries
            suppressNextWatch = true
            try GitConfigFileManager(path: filePath).save(entries)
            startWatching(path: filePath)
        } catch {
            suppressNextWatch = false
            showError(message: "Failed to save git config: \(error.localizedDescription)")
        }
    }

    private var backupPath: String? {
        guard let filePath else { return nil }
        return URL(fileURLWithPath: filePath).resolvingSymlinksInPath().path + ".bak"
    }

    var hasBackup: Bool {
        guard let backupPath else { return false }
        return FileManager.default.fileExists(atPath: backupPath)
    }

    func restoreFromBackup() {
        guard let filePath, let backupPath, FileManager.default.fileExists(atPath: backupPath) else { return }
        let target = URL(fileURLWithPath: filePath).resolvingSymlinksInPath().path
        do {
            suppressNextWatch = true
            try FileManager.default.removeItem(atPath: target)
            try FileManager.default.copyItem(atPath: backupPath, toPath: target)
            loadEntries()
        } catch {
            suppressNextWatch = false
            showError(message: "Failed to restore backup: \(error.localizedDescription)")
        }
    }

    func discardChanges() {
        workingEntries = entries
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    private var isUndoing = false

    private func registerUndo(oldValue: [GitConfigEntry]) {
        guard !isUndoing, let undoManager, oldValue != workingEntries else { return }
        undoManager.registerUndo(withTarget: self) { [oldValue] target in
            target.isUndoing = true
            target.workingEntries = oldValue
            target.isUndoing = false
        }
    }

    func sendFileChangedNotification(fileName: String) {
        guard !NSApp.isActive else { return }
        let content = UNMutableNotificationContent()
        content.title = "File Changed"
        content.body = "\(fileName) was modified externally."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "file-changed-git-config", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
