import Foundation
import SwiftUI

@MainActor
final class AliasViewModel: ObservableObject {
    @Published var aliases: [Alias] = []
    @Published var workingAliases: [Alias] = [] {
        didSet { registerUndo(oldValue: oldValue) }
    }
    var undoManager: UndoManager?
    @Published var searchText: String = ""
    @Published var sortOrder: SortOrder = .none
    private var preSortOrder: [Alias]?
    @Published var filePath: String?
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showSourceReminder = false
    @Published var fileChangedExternally = false
    private var fileWatcher: FileWatcher?
    private var suppressNextWatch = false

    private static let filePathKey = "aliasFilePath"
    private static let sortOrderKey = "aliasSortOrder"
    private static let suppressReminderKey = "suppressSourceReminder"
    private static let recentFilesKey = "aliasRecentFiles"

    var recentFiles: [String] {
        UserDefaults.standard.stringArray(forKey: Self.recentFilesKey) ?? []
    }

    var hasUnsavedChanges: Bool {
        aliases != workingAliases
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
        for alias in workingAliases {
            if !alias.group.isEmpty && seen.insert(alias.group).inserted {
                result.append(alias.group)
            }
        }
        return result
    }

    var groupedAliases: [(group: String, aliases: [Alias])] {
        let filtered = displayedAliases
        var order: [String] = []
        var grouped: [String: [Alias]] = [:]

        for alias in filtered {
            if grouped[alias.group] == nil {
                order.append(alias.group)
            }
            grouped[alias.group, default: []].append(alias)
        }

        return order.map { (group: $0, aliases: grouped[$0]!) }
    }

    var displayedAliases: [Alias] {
        var result = workingAliases

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.command.lowercased().contains(query) ||
                $0.group.lowercased().contains(query)
            }
        }

        return result
    }

    func applySort() {
        UserDefaults.standard.set(sortOrder.rawValue, forKey: Self.sortOrderKey)

        if sortOrder == .none {
            if let original = preSortOrder {
                workingAliases = original
                preSortOrder = nil
            }
            return
        }

        if preSortOrder == nil {
            preSortOrder = workingAliases
        }

        var groupOrder: [String] = []
        var grouped: [String: [Alias]] = [:]

        for alias in workingAliases {
            if grouped[alias.group] == nil {
                groupOrder.append(alias.group)
            }
            grouped[alias.group, default: []].append(alias)
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

        let aliasComparator: (Alias, Alias) -> Bool = ascending
            ? { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            : { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }

        workingAliases = groupOrder.flatMap { group in
            grouped[group]!.sorted(by: aliasComparator)
        }
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
        loadAliases()
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
            .appendingPathComponent(".aliases.zsh").path
        FileManager.default.createFile(atPath: path, contents: nil)
        filePath = path
        UserDefaults.standard.set(path, forKey: Self.filePathKey)
        addToRecentFiles(path)
        aliases = []
        workingAliases = []
        startWatching(path: path)
    }

    func loadAliases() {
        guard let filePath else { return }
        do {
            let manager = AliasFileManager(path: filePath)
            aliases = try manager.load()
            workingAliases = aliases
            if sortOrder != .none {
                applySort()
            }
            startWatching(path: filePath)
        } catch {
            showError(message: "Failed to load aliases: \(error.localizedDescription)")
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
        }
        fileWatcher?.watch(path: path)
    }

    func reloadFromDisk() {
        fileChangedExternally = false
        loadAliases()
    }

    @discardableResult
    func addAlias(name: String, command: String, group: String) -> Bool {
        guard !name.isEmpty, !command.isEmpty else { return false }

        if !Self.isValidAliasName(name) {
            showError(message: "'\(name)' is not a valid alias name. Avoid spaces, quotes, and special characters (=, ;, &, |).")
            return false
        }

        if workingAliases.contains(where: { $0.name == name }) {
            showError(message: "An alias named '\(name)' already exists.")
            return false
        }

        let newAlias = Alias(name: name, command: command, group: group)

        if group.isEmpty {
            workingAliases.append(newAlias)
        } else if let lastIndex = workingAliases.lastIndex(where: { $0.group == group }) {
            workingAliases.insert(newAlias, at: workingAliases.index(after: lastIndex))
        } else {
            workingAliases.append(newAlias)
        }

        if sortOrder != .none {
            applySort()
        }

        return true
    }

    func updateAlias(id: UUID, name: String, command: String, group: String) -> Bool {
        guard !name.isEmpty, !command.isEmpty else { return false }

        if !Self.isValidAliasName(name) {
            showError(message: "'\(name)' is not a valid alias name. Avoid spaces, quotes, and special characters (=, ;, &, |).")
            return false
        }

        if workingAliases.contains(where: { $0.name == name && $0.id != id }) {
            showError(message: "An alias named '\(name)' already exists.")
            return false
        }

        guard let index = workingAliases.firstIndex(where: { $0.id == id }) else { return false }
        let isEnabled = workingAliases[index].isEnabled
        workingAliases[index] = Alias(id: id, name: name, command: command, group: group, isEnabled: isEnabled)
        return true
    }

    func renameGroup(from oldName: String, to newName: String) {
        for index in workingAliases.indices where workingAliases[index].group == oldName {
            workingAliases[index].group = newName
        }
    }

    func moveAliases(in group: String, from source: IndexSet, to destination: Int) {
        var groupAliases = workingAliases.filter { $0.group == group }
        groupAliases.move(fromOffsets: source, toOffset: destination)

        var result: [Alias] = []
        var groupInserted = false
        for alias in workingAliases {
            if alias.group == group {
                if !groupInserted {
                    result.append(contentsOf: groupAliases)
                    groupInserted = true
                }
            } else {
                result.append(alias)
            }
        }
        if !groupInserted {
            result.append(contentsOf: groupAliases)
        }

        workingAliases = result
    }

    func toggleEnabled(_ alias: Alias) {
        guard let index = workingAliases.firstIndex(where: { $0.id == alias.id }) else { return }
        workingAliases[index].isEnabled.toggle()
    }

    func duplicateAlias(_ alias: Alias) {
        var newName = alias.name + "-copy"
        var counter = 2
        while workingAliases.contains(where: { $0.name == newName }) {
            newName = alias.name + "-copy\(counter)"
            counter += 1
        }
        let copy = Alias(name: newName, command: alias.command, group: alias.group, isEnabled: alias.isEnabled)
        if let index = workingAliases.firstIndex(where: { $0.id == alias.id }) {
            workingAliases.insert(copy, at: workingAliases.index(after: index))
        } else {
            workingAliases.append(copy)
        }
    }

    func deleteAlias(_ alias: Alias) {
        workingAliases.removeAll { $0.id == alias.id }
    }

    func deleteAliases(at offsets: IndexSet) {
        let displayed = displayedAliases
        let idsToRemove = offsets.map { displayed[$0].id }
        workingAliases.removeAll { idsToRemove.contains($0.id) }
    }

    func bulkSetEnabled(_ ids: Set<UUID>, enabled: Bool) {
        for index in workingAliases.indices where ids.contains(workingAliases[index].id) {
            workingAliases[index].isEnabled = enabled
        }
    }

    func bulkDelete(_ ids: Set<UUID>) {
        workingAliases.removeAll { ids.contains($0.id) }
    }

    func dependents(of aliasName: String) -> [String] {
        return workingAliases
            .filter { $0.name != aliasName && commandReferences(command: $0.command, aliasName: aliasName) }
            .map(\.name)
    }

    func dependencies(of alias: Alias) -> [String] {
        return Set(workingAliases.map(\.name)).filter { name in
            name != alias.name && commandReferences(command: alias.command, aliasName: name)
        }.sorted()
    }

    private func commandReferences(command: String, aliasName: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: aliasName)
        let pattern = "(^|[\\s;&|])\(escaped)($|[\\s;&|])"
        return command.range(of: pattern, options: .regularExpression) != nil
    }

    func replaceInCommands(find: String, replaceWith: String) {
        guard !find.isEmpty else { return }
        for index in workingAliases.indices where workingAliases[index].command.contains(find) {
            workingAliases[index].command = workingAliases[index].command.replacingOccurrences(of: find, with: replaceWith)
        }
    }

    func bulkSetGroup(_ ids: Set<UUID>, group: String) {
        for index in workingAliases.indices where ids.contains(workingAliases[index].id) {
            workingAliases[index].group = group
        }
    }

    func saveChanges() {
        guard let filePath else { return }
        do {
            aliases = workingAliases
            preSortOrder = nil
            suppressNextWatch = true
            let manager = AliasFileManager(path: filePath)
            try manager.save(aliases)
            startWatching(path: filePath)
            if !UserDefaults.standard.bool(forKey: Self.suppressReminderKey) {
                showSourceReminder = true
            }
        } catch {
            suppressNextWatch = false
            showError(message: "Failed to save aliases: \(error.localizedDescription)")
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
            loadAliases()
        } catch {
            suppressNextWatch = false
            showError(message: "Failed to restore backup: \(error.localizedDescription)")
        }
    }

    func discardChanges() {
        workingAliases = aliases
    }

    func importAliases(from url: URL) -> Int {
        do {
            let imported = try AliasFileManager.loadAliases(from: url)
            guard !imported.isEmpty else {
                showError(message: "No aliases found in the selected file.")
                return 0
            }

            var addedCount = 0
            for alias in imported where !workingAliases.contains(where: { $0.name == alias.name }) {
                workingAliases.append(alias)
                addedCount += 1
            }

            if addedCount == 0 {
                showError(message: "All \(imported.count) aliases in the file already exist. No new aliases imported.")
            }

            return addedCount
        } catch {
            showError(message: "Failed to import file: \(error.localizedDescription)")
            return 0
        }
    }

    private static let invalidAliasChars = CharacterSet.whitespaces
        .union(.init(charactersIn: "='\"`;|&()<>"))

    static func isValidAliasName(_ name: String) -> Bool {
        name.rangeOfCharacter(from: invalidAliasChars) == nil
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    func exportContent(for ids: Set<UUID>? = nil) -> String {
        let items = ids.map { selected in
            workingAliases.filter { selected.contains($0.id) }
        } ?? workingAliases
        return AliasFileManager.serialize(aliases: items)
    }

    nonisolated func shadowWarning(for name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [trimmed]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.availableData
            if process.terminationStatus == 0,
               let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return "Shadows \(path)"
            }
        } catch {}
        return nil
    }

    private var isUndoing = false

    private func registerUndo(oldValue: [Alias]) {
        guard !isUndoing, let undoManager, oldValue != workingAliases else { return }
        undoManager.registerUndo(withTarget: self) { [oldValue] target in
            target.isUndoing = true
            target.workingAliases = oldValue
            target.isUndoing = false
        }
    }
}
