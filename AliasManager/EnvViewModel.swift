import Foundation
import SwiftUI

@MainActor
final class EnvViewModel: ObservableObject {
    @Published var variables: [EnvVariable] = []
    @Published var workingVariables: [EnvVariable] = []
    @Published var searchText: String = ""
    @Published var sortOrder: SortOrder = .none
    private var preSortOrder: [EnvVariable]?
    @Published var filePath: String?
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showSourceReminder = false

    private static let filePathKey = "envFilePath"
    private static let sortOrderKey = "envSortOrder"
    private static let suppressReminderKey = "suppressSourceReminder"

    enum SortOrder: Int {
        case none = 0, ascending = 1, descending = 2

        var systemImage: String {
            switch self {
            case .none: return "arrow.up.arrow.down"
            case .ascending: return "arrow.up"
            case .descending: return "arrow.down"
            }
        }

        mutating func toggle() {
            switch self {
            case .none: self = .ascending
            case .ascending: self = .descending
            case .descending: self = .none
            }
        }
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
        loadVariables()
    }

    func createDefault() {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".env.zsh").path
        FileManager.default.createFile(atPath: path, contents: nil)
        filePath = path
        UserDefaults.standard.set(path, forKey: Self.filePathKey)
        variables = []
        workingVariables = []
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
        } catch {
            showError(message: "Failed to load variables: \(error.localizedDescription)")
        }
    }

    func addVariable(name: String, value: String, group: String) -> Bool {
        guard !name.isEmpty, !value.isEmpty else { return false }

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

        if workingVariables.contains(where: { $0.name == name && $0.id != id }) {
            showError(message: "A variable named '\(name)' already exists.")
            return false
        }

        guard let index = workingVariables.firstIndex(where: { $0.id == id }) else { return false }
        let isSecret = workingVariables[index].isSecret
        workingVariables[index] = EnvVariable(id: id, name: name, value: value, group: group, isSecret: isSecret)
        return true
    }

    func renameGroup(from oldName: String, to newName: String) {
        for index in workingVariables.indices {
            if workingVariables[index].group == oldName {
                workingVariables[index].group = newName
            }
        }
    }

    func toggleSecret(_ variable: EnvVariable) {
        guard let index = workingVariables.firstIndex(where: { $0.id == variable.id }) else { return }
        workingVariables[index].isSecret.toggle()
    }

    func deleteVariable(_ variable: EnvVariable) {
        workingVariables.removeAll { $0.id == variable.id }
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
            let manager = EnvFileManager(path: filePath)
            try manager.save(variables)
            if !UserDefaults.standard.bool(forKey: Self.suppressReminderKey) {
                showSourceReminder = true
            }
        } catch {
            showError(message: "Failed to save variables: \(error.localizedDescription)")
        }
    }

    func suppressReminder() {
        UserDefaults.standard.set(true, forKey: Self.suppressReminderKey)
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
            for variable in imported {
                if !workingVariables.contains(where: { $0.name == variable.name }) {
                    workingVariables.append(variable)
                    addedCount += 1
                }
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

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
