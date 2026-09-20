import Foundation

/// Checks whether an alias name conflicts with an existing system command
/// by searching common executable paths. Results are cached to avoid
/// repeated filesystem lookups.
final class CommandConflictChecker: @unchecked Sendable {
    static let shared = CommandConflictChecker()

    /// Directories searched for executable conflicts, ordered by priority.
    static let defaultSearchPaths: [String] = [
        "/usr/local/bin",
        "/opt/homebrew/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
    ]

    private let searchPaths: [String]
    private let lock = NSLock()
    private var cache: [String: String?] = [:]

    init(searchPaths: [String] = CommandConflictChecker.defaultSearchPaths) {
        self.searchPaths = searchPaths
    }

    /// Returns the path of a system command that the given alias name would
    /// shadow, or `nil` if no conflict is found.
    func conflictingPath(for name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        lock.lock()
        if let cached = cache[trimmed] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let result = findExecutable(named: trimmed)

        lock.lock()
        cache[trimmed] = result
        lock.unlock()

        return result
    }

    /// Clears the cached results, forcing fresh filesystem lookups on the
    /// next call to ``conflictingPath(for:)``.
    func clearCache() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }

    // MARK: - Private

    private func findExecutable(named name: String) -> String? {
        let fm = FileManager.default
        for dir in searchPaths {
            let path = (dir as NSString).appendingPathComponent(name)
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }
}
