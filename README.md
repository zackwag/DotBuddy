# DotBuddy

A macOS app for managing shell aliases and environment variables through a visual interface.

[![Download](https://img.shields.io/github/v/release/zackwag/DotBuddy?label=Download&style=flat-square)](https://github.com/zackwag/DotBuddy/releases/latest)

![Home](screenshots/home.png)

## Features

### Aliases

![Aliases](screenshots/aliases.png)

- Add, edit, delete, and reorder shell aliases
- Enable/disable aliases (disabled entries are commented with `##` in the file)
- Group aliases with comment headers (written as `# Group Name` in the file)
- Rename, collapse/expand, and create new groups
- Multi-select with bulk actions (enable, disable, delete, move to group)
- Sort alphabetically (groups and items within)
- Import aliases from any file
- Copy commands to clipboard

### Environment Variables

![Environment](screenshots/environment.png)

- Full CRUD for `export KEY="value"` entries
- Enable/disable variables (disabled entries are commented with `##` in the file)
- Automatic type detection (bool, int, path, url, email, arn, uuid, args, secret)
- Mark variables as secret — values are hidden by default
- Touch ID required to reveal or copy secret values
- Secret flag persists in the file as a trailing `# [secret]` comment
- Multi-select with bulk actions (enable, disable, delete, move to group)

### Snippet Library
- Browse curated alias and environment variable suggestions
- Categories include Git, Docker, Kubernetes, Node.js, Python, and more
- Sourced from oh-my-zsh plugin aliases
- Detects items already in your files
- Add individually or bulk-add with a group picker
- Library data fetched from a live remote source, with bundled fallback

### General
- Choose any dotfile or create defaults (`~/.aliases.zsh`, `~/.env.zsh`)
- Recent files menu for quick switching between dotfiles
- Drag & drop file import onto the list
- Hidden files visible in the file picker
- Groups with collapsible disclosure
- Drag-to-reorder within groups
- Find & replace across all commands/values (Cmd+Shift+H)
- Unsaved changes tracking with save/discard
- Auto-backup (`.bak`) before every save, with one-click restore
- Quit confirmation when unsaved changes exist
- File watcher detects external edits and offers to reload
- Shadow detection warns when alias names conflict with system binaries
- Alias dependency tracking — shows which aliases reference each other
- Shell history analysis suggests aliases for frequently typed commands
- Menu bar icon for quick search, copy commands, and toggle enable/disable
- Keyboard shortcuts (Escape to dismiss, Delete for bulk actions, Cmd+N/S/I/E)
- Undo/Redo support (Cmd+Z)
- Sort order persists between sessions
- Post-save reminder to source the file (dismissible)
- Alternating row backgrounds
- Hover-reactive icon buttons

## Install

### Homebrew

```sh
brew install zackwag/tap/dotbuddy
```

### Manual

Download the latest release from the [Releases page](https://github.com/zackwag/DotBuddy/releases/latest). Unzip and drag `DotBuddy.app` to your Applications folder.

The app is signed and notarized — no Gatekeeper warnings.

## Requirements

- macOS 14.5+

## Setup

On first launch, select an existing aliases/env file or click "Create Default" to generate one.

Make sure your shell config sources the file:

```zsh
# In ~/.zshrc
source ~/.aliases.zsh
source ~/.env.zsh
```

## File Format

### Aliases
```zsh
# Git Aliases
alias commit='git commit'
alias uncommit='git reset --soft HEAD^'
## alias old='disabled alias'

# Brew Aliases
alias brew_refresh='brew update && brew upgrade && brew cleanup'
```

### Environment Variables
```zsh
# AWS Vars
export AWS_PROFILE="my-profile"
export AWS_REGION="us-east-1"
## export OLD_VAR="disabled"

# Secrets
export GITHUB_ACCESS_TOKEN="ghp_xxxx" # [secret]
```

Lines prefixed with `##` are disabled entries — they are preserved in the file but inactive.

## Building from Source

1. Clone the repo
2. Install SwiftLint: `brew install swiftlint`
3. Open `DotBuddy.xcodeproj` in Xcode
4. Build and run

Requires Xcode 15.4+. SwiftLint runs automatically as a build phase.

## License

MIT License. See [LICENSE](LICENSE) for details.
