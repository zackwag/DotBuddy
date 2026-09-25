import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class KnownHostsViewModel: ObservableObject {
    @Published var hosts: [KnownHost] = []
    @Published var workingHosts: [KnownHost] = [] {
        didSet { registerUndo(oldValue: oldValue) }
    }
    var undoManager: UndoManager?
    @Published var searchText: String = ""
    @Published var sortOrder: SortOrder = .none
    private var preSortOrder: [KnownHost]?
    @Published var filePath: String?
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var fileChangedExternally = false
    @Published var testResults: [KnownHostTestResult] = []
    @Published var isTesting = false
    @Published var showTestResults = false
    var testSkippedCount = 0
    private var fileWatcher: FileWatcher?
    private var suppressNextWatch = false

    private static let filePathKey = "knownHostsFilePath"
    private static let sortOrderKey = "knownHostsSortOrder"

    var hasUnsavedChanges: Bool {
        hosts != workingHosts
    }

    var hasFile: Bool {
        filePath != nil
    }

    var fileName: String {
        guard let filePath else { return "No file selected" }
        return (filePath as NSString).lastPathComponent
    }

    var displayedHosts: [KnownHost] {
        var result = workingHosts

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.hostnames.lowercased().contains(query) ||
                $0.keyType.lowercased().contains(query)
            }
        }

        return result
    }

    init() {
        filePath = UserDefaults.standard.string(forKey: Self.filePathKey)
        let rawSort = UserDefaults.standard.integer(forKey: Self.sortOrderKey)
        sortOrder = SortOrder(rawValue: rawSort) ?? .none
    }

    func selectFile(url: URL) {
        let path = url.path
        filePath = path
        UserDefaults.standard.set(path, forKey: Self.filePathKey)
        loadHosts()
    }

    func useDefault() {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh/known_hosts").path
        guard FileManager.default.fileExists(atPath: path) else {
            showError(message: "No known_hosts file found at ~/.ssh/known_hosts")
            return
        }
        filePath = path
        UserDefaults.standard.set(path, forKey: Self.filePathKey)
        loadHosts()
    }

    func loadHosts() {
        guard let filePath else { return }
        do {
            let manager = KnownHostsFileManager(path: filePath)
            hosts = try manager.load()
            workingHosts = hosts
            if sortOrder != .none { applySort() }
            startWatching(path: filePath)
        } catch {
            showError(message: "Failed to load known hosts: \(error.localizedDescription)")
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
        loadHosts()
    }

    func duplicateHost(_ host: KnownHost) {
        let copy = KnownHost(
            hostnames: host.hostnames,
            keyType: host.keyType,
            publicKey: host.publicKey,
            isHashed: host.isHashed
        )
        if let index = workingHosts.firstIndex(where: { $0.id == host.id }) {
            workingHosts.insert(copy, at: workingHosts.index(after: index))
        } else {
            workingHosts.append(copy)
        }
    }

    func deleteHost(_ host: KnownHost) {
        workingHosts.removeAll { $0.id == host.id }
    }

    func bulkDelete(_ ids: Set<UUID>) {
        workingHosts.removeAll { ids.contains($0.id) }
    }

    func applySort() {
        UserDefaults.standard.set(sortOrder.rawValue, forKey: Self.sortOrderKey)

        if sortOrder == .none {
            if let original = preSortOrder {
                workingHosts = original
                preSortOrder = nil
            }
            return
        }

        if preSortOrder == nil {
            preSortOrder = workingHosts
        }

        let ascending = sortOrder == .ascending
        workingHosts.sort { a, b in
            ascending
                ? a.hostnames.localizedCaseInsensitiveCompare(b.hostnames) == .orderedAscending
                : a.hostnames.localizedCaseInsensitiveCompare(b.hostnames) == .orderedDescending
        }
    }

    func testAllHosts() {
        let testable = workingHosts.filter { !$0.isHashed }
        testSkippedCount = workingHosts.count - testable.count
        testResults = testable.map {
            KnownHostTestResult(id: $0.id, hostname: $0.hostnameList.first ?? $0.hostnames, status: .idle)
        }
        isTesting = true
        showTestResults = true

        Task.detached { [testable] in
            for host in testable {
                let firstHost = host.hostnameList.first ?? host.hostnames
                let target = KnownHostTester.HostTarget(raw: firstHost)
                await MainActor.run { [weak self] in
                    if let idx = self?.testResults.firstIndex(where: { $0.id == host.id }) {
                        self?.testResults[idx] = KnownHostTestResult(id: host.id, hostname: firstHost, status: .testing)
                    }
                }
                let success = KnownHostTester.test(target: target)
                await MainActor.run { [weak self] in
                    if let idx = self?.testResults.firstIndex(where: { $0.id == host.id }) {
                        self?.testResults[idx] = KnownHostTestResult(
                            id: host.id, hostname: firstHost, status: success ? .success : .failure
                        )
                    }
                }
            }
            await MainActor.run { [weak self] in
                self?.isTesting = false
            }
        }
    }

    func removeHostsByIDs(_ ids: Set<UUID>) {
        workingHosts.removeAll { ids.contains($0.id) }
        testResults.removeAll { ids.contains($0.id) }
    }

    func saveChanges() {
        guard let filePath else { return }
        do {
            hosts = workingHosts
            preSortOrder = nil
            suppressNextWatch = true
            let manager = KnownHostsFileManager(path: filePath)
            try manager.save(hosts)
            startWatching(path: filePath)
        } catch {
            suppressNextWatch = false
            showError(message: "Failed to save known hosts: \(error.localizedDescription)")
        }
    }

    var hasBackup: Bool {
        guard let filePath else { return false }
        return FileManager.default.fileExists(atPath: filePath + ".bak")
    }

    func restoreFromBackup() {
        guard let filePath else { return }
        let backupPath = filePath + ".bak"
        guard FileManager.default.fileExists(atPath: backupPath) else { return }
        do {
            suppressNextWatch = true
            try FileManager.default.removeItem(atPath: filePath)
            try FileManager.default.copyItem(atPath: backupPath, toPath: filePath)
            loadHosts()
        } catch {
            suppressNextWatch = false
            showError(message: "Failed to restore backup: \(error.localizedDescription)")
        }
    }

    func exportContent() -> String {
        KnownHostsFileManager.serialize(hosts: workingHosts)
    }

    func importHosts(from url: URL) -> Int {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return 0 }
        let parsed = KnownHostsFileManager.parseHosts(from: contents)
        let existingKeys = Set(workingHosts.map { "\($0.hostnames) \($0.keyType)" })
        var count = 0
        for host in parsed {
            let key = "\(host.hostnames) \(host.keyType)"
            if !existingKeys.contains(key) {
                workingHosts.append(host)
                count += 1
            }
        }
        return count
    }

    func discardChanges() {
        workingHosts = hosts
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    private var isUndoing = false

    private func registerUndo(oldValue: [KnownHost]) {
        guard !isUndoing, let undoManager, oldValue != workingHosts else { return }
        undoManager.registerUndo(withTarget: self) { [oldValue] target in
            target.isUndoing = true
            target.workingHosts = oldValue
            target.isUndoing = false
        }
    }

    func sendFileChangedNotification(fileName: String) {
        guard !NSApp.isActive else { return }
        let content = UNMutableNotificationContent()
        content.title = "File Changed"
        content.body = "\(fileName) was modified externally."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "file-changed-known-hosts", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
