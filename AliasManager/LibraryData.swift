import Foundation

enum LibraryItemType {
    case alias
    case environment
}

struct LibraryItem: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let description: String
    let type: LibraryItemType
    let category: String
}

struct LibraryCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let items: [LibraryItem]
}

struct LibraryData {
    static let aliasCategories: [LibraryCategory] = [
        LibraryCategory(name: "Navigation", icon: "folder", items: [
            LibraryItem(name: "..", value: "cd ..", description: "Go up one directory", type: .alias, category: "Navigation"),
            LibraryItem(name: "...", value: "cd ../..", description: "Go up two directories", type: .alias, category: "Navigation"),
            LibraryItem(name: "~", value: "cd ~", description: "Go to home directory", type: .alias, category: "Navigation"),
            LibraryItem(name: "mkcd", value: "mkdir -p \"$1\" && cd \"$1\"", description: "Create directory and cd into it", type: .alias, category: "Navigation"),
        ]),
        LibraryCategory(name: "File Listing", icon: "list.bullet", items: [
            LibraryItem(name: "ll", value: "ls -lah", description: "Long list with hidden files", type: .alias, category: "File Listing"),
            LibraryItem(name: "la", value: "ls -A", description: "List all except . and ..", type: .alias, category: "File Listing"),
            LibraryItem(name: "lt", value: "ls -ltrh", description: "List sorted by date, newest last", type: .alias, category: "File Listing"),
            LibraryItem(name: "lsize", value: "ls -lSrh", description: "List sorted by size", type: .alias, category: "File Listing"),
        ]),
        LibraryCategory(name: "Git", icon: "arrow.triangle.branch", items: [
            LibraryItem(name: "gs", value: "git status", description: "Git status", type: .alias, category: "Git"),
            LibraryItem(name: "ga", value: "git add", description: "Git add", type: .alias, category: "Git"),
            LibraryItem(name: "gc", value: "git commit", description: "Git commit", type: .alias, category: "Git"),
            LibraryItem(name: "gcm", value: "git commit -m", description: "Git commit with message", type: .alias, category: "Git"),
            LibraryItem(name: "gp", value: "git push", description: "Git push", type: .alias, category: "Git"),
            LibraryItem(name: "gpl", value: "git pull", description: "Git pull", type: .alias, category: "Git"),
            LibraryItem(name: "gco", value: "git checkout", description: "Git checkout", type: .alias, category: "Git"),
            LibraryItem(name: "gb", value: "git branch", description: "Git branch", type: .alias, category: "Git"),
            LibraryItem(name: "gl", value: "git log --oneline --graph --decorate", description: "Pretty git log", type: .alias, category: "Git"),
            LibraryItem(name: "gd", value: "git diff", description: "Git diff", type: .alias, category: "Git"),
            LibraryItem(name: "gst", value: "git stash", description: "Git stash", type: .alias, category: "Git"),
            LibraryItem(name: "gstp", value: "git stash pop", description: "Git stash pop", type: .alias, category: "Git"),
        ]),
        LibraryCategory(name: "Docker", icon: "shippingbox", items: [
            LibraryItem(name: "dps", value: "docker ps", description: "List running containers", type: .alias, category: "Docker"),
            LibraryItem(name: "dpsa", value: "docker ps -a", description: "List all containers", type: .alias, category: "Docker"),
            LibraryItem(name: "dimg", value: "docker images", description: "List images", type: .alias, category: "Docker"),
            LibraryItem(name: "dex", value: "docker exec -it", description: "Exec into container", type: .alias, category: "Docker"),
            LibraryItem(name: "dlog", value: "docker logs -f", description: "Follow container logs", type: .alias, category: "Docker"),
            LibraryItem(name: "dcu", value: "docker compose up -d", description: "Compose up detached", type: .alias, category: "Docker"),
            LibraryItem(name: "dcd", value: "docker compose down", description: "Compose down", type: .alias, category: "Docker"),
        ]),
        LibraryCategory(name: "Kubernetes", icon: "cpu", items: [
            LibraryItem(name: "k", value: "kubectl", description: "Kubectl shorthand", type: .alias, category: "Kubernetes"),
            LibraryItem(name: "kgp", value: "kubectl get pods", description: "Get pods", type: .alias, category: "Kubernetes"),
            LibraryItem(name: "kgs", value: "kubectl get svc", description: "Get services", type: .alias, category: "Kubernetes"),
            LibraryItem(name: "kgd", value: "kubectl get deployments", description: "Get deployments", type: .alias, category: "Kubernetes"),
            LibraryItem(name: "kl", value: "kubectl logs -f", description: "Follow pod logs", type: .alias, category: "Kubernetes"),
            LibraryItem(name: "kex", value: "kubectl exec -it", description: "Exec into pod", type: .alias, category: "Kubernetes"),
            LibraryItem(name: "kctx", value: "kubectl config use-context", description: "Switch context", type: .alias, category: "Kubernetes"),
        ]),
        LibraryCategory(name: "Python", icon: "chevron.left.forwardslash.chevron.right", items: [
            LibraryItem(name: "py", value: "python3", description: "Python 3", type: .alias, category: "Python"),
            LibraryItem(name: "pip", value: "pip3", description: "Pip 3", type: .alias, category: "Python"),
            LibraryItem(name: "venv", value: "python3 -m venv .venv", description: "Create virtual environment", type: .alias, category: "Python"),
            LibraryItem(name: "activate", value: "source .venv/bin/activate", description: "Activate venv", type: .alias, category: "Python"),
        ]),
        LibraryCategory(name: "Node.js", icon: "cube", items: [
            LibraryItem(name: "ni", value: "npm install", description: "npm install", type: .alias, category: "Node.js"),
            LibraryItem(name: "nr", value: "npm run", description: "npm run", type: .alias, category: "Node.js"),
            LibraryItem(name: "nrd", value: "npm run dev", description: "npm run dev", type: .alias, category: "Node.js"),
            LibraryItem(name: "nrb", value: "npm run build", description: "npm run build", type: .alias, category: "Node.js"),
            LibraryItem(name: "nrt", value: "npm run test", description: "npm run test", type: .alias, category: "Node.js"),
        ]),
        LibraryCategory(name: "System", icon: "desktopcomputer", items: [
            LibraryItem(name: "ports", value: "lsof -i -P -n | grep LISTEN", description: "Show listening ports", type: .alias, category: "System"),
            LibraryItem(name: "myip", value: "curl -s ifconfig.me", description: "Show public IP", type: .alias, category: "System"),
            LibraryItem(name: "flushdns", value: "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder", description: "Flush DNS cache (macOS)", type: .alias, category: "System"),
            LibraryItem(name: "top10", value: "ps aux | sort -nrk 3,3 | head -10", description: "Top 10 CPU processes", type: .alias, category: "System"),
            LibraryItem(name: "diskuse", value: "du -sh * | sort -rh | head -20", description: "Disk usage sorted by size", type: .alias, category: "System"),
            LibraryItem(name: "weather", value: "curl -s wttr.in/?format=3", description: "Quick weather report", type: .alias, category: "System"),
        ]),
    ]

    static let envCategories: [LibraryCategory] = [
        LibraryCategory(name: "Shell", icon: "terminal", items: [
            LibraryItem(name: "EDITOR", value: "vim", description: "Default text editor", type: .environment, category: "Shell"),
            LibraryItem(name: "VISUAL", value: "code --wait", description: "Visual editor for git, etc.", type: .environment, category: "Shell"),
            LibraryItem(name: "LANG", value: "en_US.UTF-8", description: "Default locale", type: .environment, category: "Shell"),
            LibraryItem(name: "HISTSIZE", value: "10000", description: "Shell history size", type: .environment, category: "Shell"),
            LibraryItem(name: "SAVEHIST", value: "10000", description: "Saved history size", type: .environment, category: "Shell"),
        ]),
        LibraryCategory(name: "Development", icon: "hammer", items: [
            LibraryItem(name: "NODE_ENV", value: "development", description: "Node.js environment", type: .environment, category: "Development"),
            LibraryItem(name: "GOPATH", value: "$HOME/go", description: "Go workspace path", type: .environment, category: "Development"),
            LibraryItem(name: "JAVA_HOME", value: "/usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home", description: "Java installation path", type: .environment, category: "Development"),
            LibraryItem(name: "PYTHON_PATH", value: "$HOME/.local/bin", description: "Python user bin directory", type: .environment, category: "Development"),
        ]),
        LibraryCategory(name: "Cloud & Infrastructure", icon: "cloud", items: [
            LibraryItem(name: "AWS_REGION", value: "us-east-1", description: "Default AWS region", type: .environment, category: "Cloud & Infrastructure"),
            LibraryItem(name: "AWS_PROFILE", value: "default", description: "AWS CLI profile", type: .environment, category: "Cloud & Infrastructure"),
            LibraryItem(name: "KUBECONFIG", value: "$HOME/.kube/config", description: "Kubernetes config file path", type: .environment, category: "Cloud & Infrastructure"),
            LibraryItem(name: "DOCKER_BUILDKIT", value: "1", description: "Enable Docker BuildKit", type: .environment, category: "Cloud & Infrastructure"),
        ]),
        LibraryCategory(name: "Path Extensions", icon: "point.topleft.down.to.point.bottomright.curvepath", items: [
            LibraryItem(name: "PATH (Homebrew)", value: "/opt/homebrew/bin:$PATH", description: "Add Homebrew to PATH (Apple Silicon)", type: .environment, category: "Path Extensions"),
            LibraryItem(name: "PATH (Go)", value: "$GOPATH/bin:$PATH", description: "Add Go binaries to PATH", type: .environment, category: "Path Extensions"),
            LibraryItem(name: "PATH (Local bin)", value: "$HOME/.local/bin:$PATH", description: "Add local bin to PATH", type: .environment, category: "Path Extensions"),
            LibraryItem(name: "PATH (Cargo)", value: "$HOME/.cargo/bin:$PATH", description: "Add Rust/Cargo to PATH", type: .environment, category: "Path Extensions"),
        ]),
        LibraryCategory(name: "Application Config", icon: "gearshape.2", items: [
            LibraryItem(name: "GPG_TTY", value: "$(tty)", description: "GPG terminal for signing", type: .environment, category: "Application Config"),
            LibraryItem(name: "FZF_DEFAULT_OPTS", value: "--height 40% --layout=reverse", description: "fzf default options", type: .environment, category: "Application Config"),
            LibraryItem(name: "BAT_THEME", value: "Dracula", description: "bat syntax highlighter theme", type: .environment, category: "Application Config"),
            LibraryItem(name: "LESS", value: "-R", description: "Less pager options (color support)", type: .environment, category: "Application Config"),
        ]),
    ]
}
