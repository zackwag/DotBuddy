import Foundation

enum LibraryItemType: String, Codable {
    case alias
    case environment
}

struct LibraryItem: Identifiable, Codable {
    var id: UUID
    let name: String
    let value: String
    let description: String
    let type: LibraryItemType
    let category: String

    init(id: UUID = UUID(), name: String, value: String, description: String, type: LibraryItemType, category: String) {
        self.id = id
        self.name = name
        self.value = value
        self.description = description
        self.type = type
        self.category = category
    }

    private enum CodingKeys: String, CodingKey {
        case name, value, description, type, category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.value = try container.decode(String.self, forKey: .value)
        self.description = try container.decode(String.self, forKey: .description)
        self.type = try container.decode(LibraryItemType.self, forKey: .type)
        self.category = try container.decode(String.self, forKey: .category)
    }
}

struct LibraryCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let items: [LibraryItem]
}

struct RemoteLibraryCategory: Codable {
    let name: String
    let items: [LibraryItem]
}

struct RemoteLibrary: Codable {
    let aliases: [RemoteLibraryCategory]
    let environment: [RemoteLibraryCategory]
}

@MainActor
final class LibraryStore: ObservableObject {
    @Published var aliasCategories: [LibraryCategory] = []
    @Published var envCategories: [LibraryCategory] = []
    @Published var isLoading = true
    @Published var isUsingBundledData = false
    private var didLoad = false

    private static let remoteURL = URL(string: "https://gist.githubusercontent.com/zackwag/fed00bf1e20538221517cffb967ebc81/raw/library.json")!

    private static let categoryIcons: [String: String] = [
        "Navigation": "folder",
        "File Listing": "list.bullet",
        "Common": "list.bullet",
        "Git": "arrow.triangle.branch",
        "Docker": "shippingbox",
        "Docker Compose": "shippingbox.2",
        "Kubernetes": "cpu",
        "Python": "chevron.left.forwardslash.chevron.right",
        "Node.js": "cube",
        "System": "desktopcomputer",
        "Shell": "terminal",
        "Development": "hammer",
        "Cloud & Infrastructure": "cloud",
        "Path Extensions": "point.topleft.down.to.point.bottomright.curvepath",
        "Application Config": "gearshape.2",
    ]

    func load() {
        guard !didLoad else { return }
        didLoad = true
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: Self.remoteURL)
                let remote = try JSONDecoder().decode(RemoteLibrary.self, from: data)
                aliasCategories = remote.aliases.map { Self.toCategory($0) }
                envCategories = remote.environment.map { Self.toCategory($0) }
            } catch {
                loadBundledFallback()
                isUsingBundledData = true
            }
            isLoading = false
        }
    }

    private static func toCategory(_ remote: RemoteLibraryCategory) -> LibraryCategory {
        LibraryCategory(
            name: remote.name,
            icon: categoryIcons[remote.name] ?? "tray",
            items: remote.items
        )
    }

    private func loadBundledFallback() {
        aliasCategories = Self.bundledAliasCategories
        envCategories = Self.bundledEnvCategories
    }

    static let bundledAliasCategories: [LibraryCategory] = [
        LibraryCategory(name: "Git", icon: "arrow.triangle.branch", items: [
            LibraryItem(name: "g", value: "git", description: "Git shorthand", type: .alias, category: "Git"),
            LibraryItem(name: "ga", value: "git add", description: "Stage files", type: .alias, category: "Git"),
            LibraryItem(name: "gaa", value: "git add --all", description: "Stage all changes", type: .alias, category: "Git"),
            LibraryItem(name: "gc", value: "git commit -v", description: "Commit with diff", type: .alias, category: "Git"),
            LibraryItem(name: "gcb", value: "git checkout -b", description: "Create and switch branch", type: .alias, category: "Git"),
            LibraryItem(name: "gco", value: "git checkout", description: "Switch branches", type: .alias, category: "Git"),
            LibraryItem(name: "gd", value: "git diff", description: "Show changes", type: .alias, category: "Git"),
            LibraryItem(name: "gst", value: "git status", description: "Show status", type: .alias, category: "Git"),
            LibraryItem(name: "gp", value: "git push", description: "Push commits", type: .alias, category: "Git"),
            LibraryItem(name: "gl", value: "git pull", description: "Pull changes", type: .alias, category: "Git"),
            LibraryItem(name: "glog", value: "git log --oneline --decorate --graph", description: "Pretty log graph", type: .alias, category: "Git"),
            LibraryItem(name: "gsta", value: "git stash push", description: "Stash changes", type: .alias, category: "Git"),
            LibraryItem(name: "gstp", value: "git stash pop", description: "Pop stash", type: .alias, category: "Git"),
        ]),
        LibraryCategory(name: "Docker", icon: "shippingbox", items: [
            LibraryItem(name: "dps", value: "docker ps", description: "List running containers", type: .alias, category: "Docker"),
            LibraryItem(name: "dpsa", value: "docker ps -a", description: "List all containers", type: .alias, category: "Docker"),
            LibraryItem(name: "drit", value: "docker container run -it", description: "Run interactive container", type: .alias, category: "Docker"),
            LibraryItem(name: "dxcit", value: "docker container exec -it", description: "Exec into container", type: .alias, category: "Docker"),
            LibraryItem(name: "dlo", value: "docker container logs", description: "View container logs", type: .alias, category: "Docker"),
            LibraryItem(name: "dstp", value: "docker container stop", description: "Stop container", type: .alias, category: "Docker"),
        ]),
        LibraryCategory(name: "Docker Compose", icon: "shippingbox.2", items: [
            LibraryItem(name: "dco", value: "docker compose", description: "Compose shorthand", type: .alias, category: "Docker Compose"),
            LibraryItem(name: "dcup", value: "docker compose up", description: "Start services", type: .alias, category: "Docker Compose"),
            LibraryItem(name: "dcupd", value: "docker compose up -d", description: "Start detached", type: .alias, category: "Docker Compose"),
            LibraryItem(name: "dcdn", value: "docker compose down", description: "Stop services", type: .alias, category: "Docker Compose"),
            LibraryItem(name: "dclf", value: "docker compose logs -f", description: "Follow logs", type: .alias, category: "Docker Compose"),
        ]),
        LibraryCategory(name: "Kubernetes", icon: "cpu", items: [
            LibraryItem(name: "k", value: "kubectl", description: "Kubectl shorthand", type: .alias, category: "Kubernetes"),
            LibraryItem(name: "kaf", value: "kubectl apply -f", description: "Apply manifest", type: .alias, category: "Kubernetes"),
            LibraryItem(name: "kgp", value: "kubectl get pods", description: "List pods", type: .alias, category: "Kubernetes"),
            LibraryItem(name: "kgs", value: "kubectl get svc", description: "List services", type: .alias, category: "Kubernetes"),
            LibraryItem(name: "kdel", value: "kubectl delete", description: "Delete resource", type: .alias, category: "Kubernetes"),
        ]),
        LibraryCategory(name: "Node.js", icon: "cube", items: [
            LibraryItem(name: "npmst", value: "npm start", description: "Start project", type: .alias, category: "Node.js"),
            LibraryItem(name: "npmt", value: "npm test", description: "Run tests", type: .alias, category: "Node.js"),
            LibraryItem(name: "npmrd", value: "npm run dev", description: "Run dev server", type: .alias, category: "Node.js"),
            LibraryItem(name: "npmrb", value: "npm run build", description: "Run build", type: .alias, category: "Node.js"),
        ]),
        LibraryCategory(name: "Python", icon: "chevron.left.forwardslash.chevron.right", items: [
            LibraryItem(name: "pipi", value: "pip install", description: "Install package", type: .alias, category: "Python"),
            LibraryItem(
                name: "pipir", value: "pip install -r requirements.txt",
                description: "Install from requirements", type: .alias, category: "Python"
            ),
            LibraryItem(name: "pyserver", value: "python3 -m http.server", description: "Start HTTP server", type: .alias, category: "Python"),
        ]),
        LibraryCategory(name: "Navigation", icon: "folder", items: [
            LibraryItem(name: "..", value: "cd ..", description: "Go up one directory", type: .alias, category: "Navigation"),
            LibraryItem(name: "...", value: "cd ../..", description: "Go up two directories", type: .alias, category: "Navigation"),
            LibraryItem(name: "~", value: "cd ~", description: "Go to home directory", type: .alias, category: "Navigation"),
        ]),
        LibraryCategory(name: "Common", icon: "list.bullet", items: [
            LibraryItem(name: "l", value: "ls -lFh", description: "List with details", type: .alias, category: "Common"),
            LibraryItem(name: "la", value: "ls -lAFh", description: "List all with details", type: .alias, category: "Common"),
            LibraryItem(name: "ll", value: "ls -l", description: "Long listing", type: .alias, category: "Common"),
            LibraryItem(name: "ff", value: "find . -type f -name", description: "Find file by name", type: .alias, category: "Common"),
            LibraryItem(name: "h", value: "history", description: "Command history", type: .alias, category: "Common"),
        ]),
        LibraryCategory(name: "System", icon: "desktopcomputer", items: [
            LibraryItem(name: "ports", value: "lsof -i -P -n | grep LISTEN", description: "Show listening ports", type: .alias, category: "System"),
            LibraryItem(name: "myip", value: "curl -s ifconfig.me", description: "Show public IP", type: .alias, category: "System"),
        ]),
    ]

    static let bundledEnvCategories: [LibraryCategory] = [
        LibraryCategory(name: "Shell", icon: "terminal", items: [
            LibraryItem(name: "EDITOR", value: "vim", description: "Default text editor", type: .environment, category: "Shell"),
            LibraryItem(name: "VISUAL", value: "code --wait", description: "Visual editor for git etc.", type: .environment, category: "Shell"),
            LibraryItem(name: "LANG", value: "en_US.UTF-8", description: "Default locale", type: .environment, category: "Shell"),
            LibraryItem(name: "HISTSIZE", value: "10000", description: "History entries in memory", type: .environment, category: "Shell"),
            LibraryItem(name: "SAVEHIST", value: "10000", description: "History entries saved to file", type: .environment, category: "Shell"),
        ]),
        LibraryCategory(name: "Development", icon: "hammer", items: [
            LibraryItem(name: "NODE_ENV", value: "development", description: "Node.js environment", type: .environment, category: "Development"),
            LibraryItem(name: "GOPATH", value: "$HOME/go", description: "Go workspace path", type: .environment, category: "Development"),
            LibraryItem(name: "PYTHONDONTWRITEBYTECODE", value: "1", description: "Skip .pyc files", type: .environment, category: "Development"),
        ]),
        LibraryCategory(name: "Path Extensions", icon: "point.topleft.down.to.point.bottomright.curvepath", items: [
            LibraryItem(
                name: "PATH", value: "$HOME/.local/bin:$PATH",
                description: "Add local bin to PATH", type: .environment, category: "Path Extensions"
            ),
        ]),
    ]
}
