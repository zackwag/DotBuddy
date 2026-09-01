import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class EnvViewModel: ObservableObject {
    @Published var variables: [EnvVariable] = []
    @Published var workingVariables: [EnvVariable] = [] {
        didSet { registerUndo(oldValue: oldValue) }
    }
    var undoManager: UndoManager?
    @Published var searchText: String = ""
    @Published var sortOrder: SortOrder = .none
    private var preSortOrder: [EnvVariable]?
    @Published var filePath: String?
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showSourceReminder = false
    @Published var fileChangedExternally = false
    private var fileWatcher: FileWatcher?
    private var suppressNextWatch = false

    private static let filePathKey = "envFilePath"
    private static let sortOrderKey = "envSortOrder"
    private static let suppressReminderKey = "suppressEnvSourceReminder"
    private static let recentFilesKey = "envRecentFiles"

    var recentFiles: [String] {
        UserDefaults.standard.stringArray(forKey: Self.recentFilesKey) ?? []
    }

    var hasUnsavedChanges: Bool {
        variables != workingVariables
    }

    var hasFile: Bool {
        filePath != nil
    }

    var fileName: String {
        guard let filePath else { return "No file selected" }
        return (filePath as NSString).lastPathComponent
    }

    var sourceCommand: String {
        guard let filePath else { return "" }
        if filePath.contains(" ") {
            return "source \"\(filePath)\""
        }
        return "source \(filePath)"
    }

    var groups: [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for variable in workingVariables {
            if !variable.group.isEmpty && seen.insert(variable.group).inserted {
                result.append(variable.group)
            }
        }
        return result
    }

    var groupedVariables: [(group: String, variables: [EnvVariable])] {
        let filtered = displayedVariables
        var order: [String] = []
        var grouped: [String: [EnvVariable]] = [:]

        for variable in filtered {
            if grouped[variable.group] == nil {
                order.append(variable.group)
            }
            grouped[variable.group, default: []].append(variable)
        }

        return order.map { (group: $0, variables: grouped[$0]!) }
    }

    var displayedVariables: [EnvVariable] {
        var result = workingVariables

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.value.lowercased().contains(query) ||
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
        addToRecentFiles(path)
        loadVariables()
    }

    private func addToRecentFiles(_ path: String) {
        var recent = UserDefaults.standard.stringArray(forKey: Self.recentFilesKey) ?? []
        recent.removeAll { $0 == path }
        recent.insert(path, at: 0)
        if recent.count > 5 { recent = Array(recent.prefix(5)) }
        UserDefaults.standard.set(recent, forKey: Self.recentFilesKey)
    }

    func createDefault() {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".env.zsh").path
        FileManager.default.createFile(atPath: path, contents: nil)
        filePath = path
        UserDefaults.standard.set(path, forKey: Self.filePathKey)
        addToRecentFiles(path)
        variables = []
        workingVariables = []
        startWatching(path: path)
    }

    func loadVariables() {
        guard let filePath else { return }
        do {
            let manager = EnvFileManager(path: filePath)
            variables = try manager.load()
            workingVariables = variables
            if sortOrder != .none {
                applySort()
            }
            startWatching(path: filePath)
        } catch {
            showError(message: "Failed to load variables: \(error.localizedDescription)")
        }
    }

    private func startWatching(path: String) {
        fileWatcher = FileWatcher { [weak self] in
            guard let self else { return }
            if self.suppressNextWatch {
                self.suppressNextWatch = false
                return
            }
            guard !self.hasUnsavedChanges else { return }
            self.fileChangedExternally = true
            self.sendFileChangedNotification(fileName: self.fileName)
        }
        fileWatcher?.watch(path: path)
    }

    func reloadFromDisk() {
        fileChangedExternally = false
        loadVariables()
    }

    @discardableResult
    func addVariable(name: String, value: String, group: String) -> Bool {
        guard !name.isEmpty, !value.isEmpty else { return false }

        if !Self.isValidEnvName(name) {
            showError(message: "'\(name)' is not a valid variable name. Use only letters, digits, and underscores.")
            return false
        }

        if workingVariables.contains(where: { $0.name == name }) {
            showError(message: "A variable named '\(name)' already exists.")
            return false
        }

        let autoSecret = ValueType.infer(from: value, name: name) == .password
        let newVar = EnvVariable(name: name, value: value, group: group, isSecret: autoSecret)

        if group.isEmpty {
            workingVariables.append(newVar)
        } else if let lastIndex = workingVariables.lastIndex(where: { $0.group == group }) {
            workingVariables.insert(newVar, at: workingVariables.index(after: lastIndex))
        } else {
            workingVariables.append(newVar)
        }

        if sortOrder != .none {
            applySort()
        }

        return true
    }

    func updateVariable(id: UUID, name: String, value: String, group: String) -> Bool {
        guard !name.isEmpty, !value.isEmpty else { return false }

        if !Self.isValidEnvName(name) {
            showError(message: "'\(name)' is not a valid variable name. Use only letters, digits, and underscores.")
            return false
        }

        if workingVariables.contains(where: { $0.name == name && $0.id != id }) {
            showError(message: "A variable named '\(name)' already exists.")
            return false
        }

        guard let index = workingVariables.firstIndex(where: { $0.id == id }) else { return false }
        let existing = workingVariables[index]
        workingVariables[index] = EnvVariable(
            id: id, name: name, value: value, group: group, isSecret: existing.isSecret, isEnabled: existing.isEnabled
        )
        return true
    }

    func renameGroup(from oldName: String, to newName: String) {
        for index in workingVariables.indices where workingVariables[index].group == oldName {
            workingVariables[index].group = newName
        }
    }

    func toggleEnabled(_ variable: EnvVariable) {
        guard let index = workingVariables.firstIndex(where: { $0.id == variable.id }) else { return }
        workingVariables[index].isEnabled.toggle()
    }

    func toggleSecret(_ variable: EnvVariable) {
        guard let index = workingVariables.firstIndex(where: { $0.id == variable.id }) else { return }
        workingVariables[index].isSecret.toggle()
    }

    func duplicateVariable(_ variable: EnvVariable) {
        var newName = variable.name + "_COPY"
        var counter = 2
        while workingVariables.contains(where: { $0.name == newName }) {
            newName = variable.name + "_COPY\(counter)"
            counter += 1
        }
        let copy = EnvVariable(name: newName, value: variable.value, group: variable.group, isSecret: variable.isSecret, isEnabled: variable.isEnabled)
        if let index = workingVariables.firstIndex(where: { $0.id == variable.id }) {
            workingVariables.insert(copy, at: workingVariables.index(after: index))
        } else {
            workingVariables.append(copy)
        }
    }

    func deleteVariable(_ variable: EnvVariable) {
        workingVariables.removeAll { $0.id == variable.id }
    }

    func bulkSetEnabled(_ ids: Set<UUID>, enabled: Bool) {
        for index in workingVariables.indices where ids.contains(workingVariables[index].id) {
            workingVariables[index].isEnabled = enabled
        }
    }

    func bulkDelete(_ ids: Set<UUID>) {
        workingVariables.removeAll { ids.contains($0.id) }
    }

    func replaceInValues(find: String, replaceWith: String) {
        guard !find.isEmpty else { return }
        for index in workingVariables.indices where workingVariables[index].value.contains(find) {
            workingVariables[index].value = workingVariables[index].value.replacingOccurrences(of: find, with: replaceWith)
        }
    }

    func bulkSetGroup(_ ids: Set<UUID>, group: String) {
        for index in workingVariables.indices where ids.contains(workingVariables[index].id) {
            workingVariables[index].group = group
        }
    }

    func moveVariables(in group: String, from source: IndexSet, to destination: Int) {
        var groupVars = workingVariables.filter { $0.group == group }
        groupVars.move(fromOffsets: source, toOffset: destination)

        var result: [EnvVariable] = []
        var groupInserted = false
        for variable in workingVariables {
            if variable.group == group {
                if !groupInserted {
                    result.append(contentsOf: groupVars)
                    groupInserted = true
                }
            } else {
                result.append(variable)
            }
        }
        if !groupInserted {
            result.append(contentsOf: groupVars)
        }

        workingVariables = result
    }

    func applySort() {
        UserDefaults.standard.set(sortOrder.rawValue, forKey: Self.sortOrderKey)

        if sortOrder == .none {
            if let original = preSortOrder {
                workingVariables = original
                preSortOrder = nil
            }
            return
        }

        if preSortOrder == nil {
            preSortOrder = workingVariables
        }

        var groupOrder: [String] = []
        var grouped: [String: [EnvVariable]] = [:]

        for variable in workingVariables {
            if grouped[variable.group] == nil {
                groupOrder.append(variable.group)
            }
            grouped[variable.group, default: []].append(variable)
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

        let varComparator: (EnvVariable, EnvVariable) -> Bool = ascending
            ? { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            : { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }

        workingVariables = groupOrder.flatMap { group in
            grouped[group]!.sorted(by: varComparator)
        }
    }

    func saveChanges() {
        guard let filePath else { return }
        do {
            variables = workingVariables
            preSortOrder = nil
            suppressNextWatch = true
            let manager = EnvFileManager(path: filePath)
            try manager.save(variables)
            startWatching(path: filePath)
            if !UserDefaults.standard.bool(forKey: Self.suppressReminderKey) {
                showSourceReminder = true
            }
        } catch {
            suppressNextWatch = false
            showError(message: "Failed to save variables: \(error.localizedDescription)")
        }
    }

    func suppressReminder() {
        UserDefaults.standard.set(true, forKey: Self.suppressReminderKey)
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
            loadVariables()
        } catch {
            suppressNextWatch = false
            showError(message: "Failed to restore backup: \(error.localizedDescription)")
        }
    }

    func discardChanges() {
        workingVariables = variables
    }

    func importVariables(from url: URL) -> Int {
        do {
            let imported = try EnvFileManager.loadVariables(from: url)
            guard !imported.isEmpty else {
                showError(message: "No environment variables found in the selected file.")
                return 0
            }

            var addedCount = 0
            for variable in imported where !workingVariables.contains(where: { $0.name == variable.name }) {
                workingVariables.append(variable)
                addedCount += 1
            }

            if addedCount == 0 {
                showError(message: "All \(imported.count) variables in the file already exist.")
            }

            return addedCount
        } catch {
            showError(message: "Failed to import file: \(error.localizedDescription)")
            return 0
        }
    }

    private static let envNamePattern = try! NSRegularExpression(pattern: "^[A-Za-z_][A-Za-z0-9_]*$")

    static func isValidEnvName(_ name: String) -> Bool {
        envNamePattern.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    func exportContent(for ids: Set<UUID>? = nil) -> String {
        let items = ids.map { selected in
            workingVariables.filter { selected.contains($0.id) }
        } ?? workingVariables
        return EnvFileManager.serialize(variables: items)
    }

    private var isUndoing = false

    private func registerUndo(oldValue: [EnvVariable]) {
        guard !isUndoing, let undoManager, oldValue != workingVariables else { return }
        undoManager.registerUndo(withTarget: self) { [oldValue] target in
            target.isUndoing = true
            target.workingVariables = oldValue
            target.isUndoing = false
        }
    }

    func sendFileChangedNotification(fileName: String) {
        guard !NSApp.isActive else { return }
        let content = UNMutableNotificationContent()
        content.title = "File Changed"
        content.body = "\(fileName) was modified externally."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "file-changed-env", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
