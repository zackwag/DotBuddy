import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class SSHViewModel: ObservableObject {
    @Published var hosts: [SSHHost] = []
    @Published var workingHosts: [SSHHost] = [] {
        didSet { registerUndo(oldValue: oldValue) }
    }
    var undoManager: UndoManager?
    @Published var searchText: String = ""
    @Published var sortOrder: SortOrder = .none
    private var preSortOrder: [SSHHost]?
    @Published var filePath: String?
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var fileChangedExternally = false
    @Published var connectionStatuses: [UUID: SSHConnectionStatus] = [:]
    @Published var testAllResults: [SSHConnectionResult] = []
    @Published var isTestingAll = false
    @Published var showTestAllResults = false
    private var fileWatcher: FileWatcher?
    private var suppressNextWatch = false

    private static let filePathKey = "sshConfigFilePath"
    private static let sortOrderKey = "sshConfigSortOrder"

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

    var groups: [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for host in workingHosts {
            if !host.group.isEmpty && seen.insert(host.group).inserted {
                result.append(host.group)
            }
        }
        return result
    }

    var groupedHosts: [(group: String, hosts: [SSHHost])] {
        let filtered = displayedHosts
        var order: [String] = []
        var grouped: [String: [SSHHost]] = [:]

        for host in filtered {
            if grouped[host.group] == nil {
                order.append(host.group)
            }
            grouped[host.group, default: []].append(host)
        }

        return order.map { (group: $0, hosts: grouped[$0]!) }
    }

    var displayedHosts: [SSHHost] {
        var result = workingHosts

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.hostPattern.lowercased().contains(query) ||
                $0.hostname.lowercased().contains(query) ||
                $0.user.lowercased().contains(query) ||
                $0.group.lowercased().contains(query)
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

    func createDefault() {
        let sshDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh")
        let path = sshDir.appendingPathComponent("config").path
        do {
            if !FileManager.default.fileExists(atPath: sshDir.path) {
                try FileManager.default.createDirectory(at: sshDir, withIntermediateDirectories: true)
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o700],
                    ofItemAtPath: sshDir.path
                )
            }
            if !FileManager.default.fileExists(atPath: path) {
                FileManager.default.createFile(atPath: path, contents: nil)
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: path
                )
            }
        } catch {
            showError(message: "Failed to create SSH config: \(error.localizedDescription)")
            return
        }
        filePath = path
        UserDefaults.standard.set(path, forKey: Self.filePathKey)
        hosts = []
        workingHosts = []
        startWatching(path: path)
    }

    func loadHosts() {
        guard let filePath else { return }
        do {
            let manager = SSHConfigFileManager(path: filePath)
            hosts = try manager.load()
            workingHosts = hosts
            if sortOrder != .none {
                applySort()
            }
            startWatching(path: filePath)
        } catch {
            showError(message: "Failed to load SSH config: \(error.localizedDescription)")
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

    @discardableResult
    func addHost(_ host: SSHHost) -> Bool {
        guard !host.hostPattern.isEmpty else { return false }

        if workingHosts.contains(where: { $0.hostPattern == host.hostPattern }) {
            showError(message: "A host entry for '\(host.hostPattern)' already exists.")
            return false
        }

        if host.group.isEmpty {
            workingHosts.append(host)
        } else if let lastIndex = workingHosts.lastIndex(where: { $0.group == host.group }) {
            workingHosts.insert(host, at: workingHosts.index(after: lastIndex))
        } else {
            workingHosts.append(host)
        }

        if sortOrder != .none { applySort() }
        return true
    }

    func updateHost(_ host: SSHHost) -> Bool {
        guard !host.hostPattern.isEmpty else { return false }

        if workingHosts.contains(where: { $0.hostPattern == host.hostPattern && $0.id != host.id }) {
            showError(message: "A host entry for '\(host.hostPattern)' already exists.")
            return false
        }

        guard let index = workingHosts.firstIndex(where: { $0.id == host.id }) else { return false }
        let existing = workingHosts[index]
        workingHosts[index] = SSHHost(
            id: host.id,
            hostPattern: host.hostPattern,
            hostname: host.hostname,
            user: host.user,
            port: host.port,
            identityFile: host.identityFile,
            otherDirectives: existing.otherDirectives,
            group: host.group,
            isEnabled: existing.isEnabled
        )
        return true
    }

    func renameGroup(from oldName: String, to newName: String) {
        for index in workingHosts.indices where workingHosts[index].group == oldName {
            workingHosts[index].group = newName
        }
    }

    func moveHosts(in group: String, from source: IndexSet, to destination: Int) {
        var groupHosts = workingHosts.filter { $0.group == group }
        groupHosts.move(fromOffsets: source, toOffset: destination)

        var result: [SSHHost] = []
        var groupInserted = false
        for host in workingHosts {
            if host.group == group {
                if !groupInserted {
                    result.append(contentsOf: groupHosts)
                    groupInserted = true
                }
            } else {
                result.append(host)
            }
        }
        if !groupInserted {
            result.append(contentsOf: groupHosts)
        }

        workingHosts = result
    }

    func toggleEnabled(_ host: SSHHost) {
        guard let index = workingHosts.firstIndex(where: { $0.id == host.id }) else { return }
        workingHosts[index].isEnabled.toggle()
    }

    func duplicateHost(_ host: SSHHost) {
        var newPattern = host.hostPattern + "-copy"
        var counter = 2
        while workingHosts.contains(where: { $0.hostPattern == newPattern }) {
            newPattern = host.hostPattern + "-copy\(counter)"
            counter += 1
        }
        let copy = SSHHost(
            hostPattern: newPattern,
            hostname: host.hostname,
            user: host.user,
            port: host.port,
            identityFile: host.identityFile,
            otherDirectives: host.otherDirectives,
            group: host.group,
            isEnabled: host.isEnabled
        )
        if let index = workingHosts.firstIndex(where: { $0.id == host.id }) {
            workingHosts.insert(copy, at: workingHosts.index(after: index))
        } else {
            workingHosts.append(copy)
        }
    }

    func deleteHost(_ host: SSHHost) {
        workingHosts.removeAll { $0.id == host.id }
    }

    func bulkSetEnabled(_ ids: Set<UUID>, enabled: Bool) {
        for index in workingHosts.indices where ids.contains(workingHosts[index].id) {
            workingHosts[index].isEnabled = enabled
        }
    }

    func bulkDelete(_ ids: Set<UUID>) {
        workingHosts.removeAll { ids.contains($0.id) }
    }

    func bulkSetGroup(_ ids: Set<UUID>, group: String) {
        for index in workingHosts.indices where ids.contains(workingHosts[index].id) {
            workingHosts[index].group = group
        }
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

        var groupOrder: [String] = []
        var grouped: [String: [SSHHost]] = [:]

        for host in workingHosts {
            if grouped[host.group] == nil {
                groupOrder.append(host.group)
            }
            grouped[host.group, default: []].append(host)
        }

        let ascending = sortOrder == .ascending
        let comparator: (String, String) -> ComparisonResult = { $0.localizedCaseInsensitiveCompare($1) }

        groupOrder.sort { a, b in
            if a.isEmpty { return !ascending }
            if b.isEmpty { return ascending }
            return ascending
                ? comparator(a, b) == .orderedAscending
                : comparator(a, b) == .orderedDescending
        }

        let hostComparator: (SSHHost, SSHHost) -> Bool = ascending
            ? { $0.hostPattern.localizedCaseInsensitiveCompare($1.hostPattern) == .orderedAscending }
            : { $0.hostPattern.localizedCaseInsensitiveCompare($1.hostPattern) == .orderedDescending }

        workingHosts = groupOrder.flatMap { group in
            grouped[group]!.sorted(by: hostComparator)
        }
    }

    func saveChanges() {
        guard let filePath else { return }
        do {
            hosts = workingHosts
            preSortOrder = nil
            suppressNextWatch = true
            let manager = SSHConfigFileManager(path: filePath)
            try manager.save(hosts)
            startWatching(path: filePath)
        } catch {
            suppressNextWatch = false
            showError(message: "Failed to save SSH config: \(error.localizedDescription)")
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

    func discardChanges() {
        workingHosts = hosts
    }

    func exportContent(for ids: Set<UUID>? = nil) -> String {
        let items = ids.map { selected in
            workingHosts.filter { selected.contains($0.id) }
        } ?? workingHosts
        return SSHConfigFileManager.serialize(hosts: items)
    }

    func importHosts(from url: URL) -> Int {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return 0 }
        let parsed = SSHConfigFileManager.parseHosts(from: contents)
        let existingPatterns = Set(workingHosts.map(\.hostPattern))
        var count = 0
        for host in parsed where !existingPatterns.contains(host.hostPattern) {
            workingHosts.append(host)
            count += 1
        }
        if sortOrder != .none { applySort() }
        return count
    }

    // MARK: - Connection Testing

    func testConnection(for host: SSHHost) {
        connectionStatuses[host.id] = .testing

        let config = SSHConnectionTester.TestConfig(hostPattern: host.hostPattern)

        Task.detached {
            let success = SSHConnectionTester.test(config: config)

            await MainActor.run {
                self.connectionStatuses[host.id] = success ? .success : .failure

                Task {
                    try? await Task.sleep(for: .seconds(4))
                    self.connectionStatuses[host.id] = .idle
                }
            }
        }
    }

    func testAllConnections() {
        let enabledHosts = workingHosts.filter(\.isEnabled)
        guard !enabledHosts.isEmpty else { return }

        isTestingAll = true
        testAllResults = enabledHosts.map {
            SSHConnectionResult(id: $0.id, hostPattern: $0.hostPattern, status: .testing)
        }
        showTestAllResults = true

        Task.detached {
            for host in enabledHosts {
                let config = SSHConnectionTester.TestConfig(hostPattern: host.hostPattern)

                await MainActor.run {
                    self.connectionStatuses[host.id] = .testing
                    if let index = self.testAllResults.firstIndex(where: { $0.id == host.id }) {
                        self.testAllResults[index] = SSHConnectionResult(
                            id: host.id, hostPattern: host.hostPattern, status: .testing
                        )
                    }
                }

                let success = SSHConnectionTester.test(config: config)
                let status: SSHConnectionStatus = success ? .success : .failure

                await MainActor.run {
                    self.connectionStatuses[host.id] = status
                    if let index = self.testAllResults.firstIndex(where: { $0.id == host.id }) {
                        self.testAllResults[index] = SSHConnectionResult(
                            id: host.id, hostPattern: host.hostPattern, status: status
                        )
                    }
                }
            }

            await MainActor.run {
                self.isTestingAll = false

                Task {
                    try? await Task.sleep(for: .seconds(6))
                    for host in enabledHosts where self.connectionStatuses[host.id] != .testing {
                        self.connectionStatuses[host.id] = .idle
                    }
                }
            }
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    private var isUndoing = false

    private func registerUndo(oldValue: [SSHHost]) {
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
        let request = UNNotificationRequest(identifier: "file-changed-ssh", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
