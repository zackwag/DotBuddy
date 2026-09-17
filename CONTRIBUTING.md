# Contributing to DotBuddy

Thanks for considering a contribution to DotBuddy, a native macOS app for managing shell aliases and environment variables.

## Getting started

```bash
git clone https://github.com/zackwag/DotBuddy.git
cd DotBuddy
open DotBuddy.xcodeproj   # or work with the DotBuddyCore SPM package directly
```

Requires Xcode with macOS 14+ SDK.

## Development

The app itself (`DotBuddy.xcodeproj`, target `DotBuddy`) is built/run through Xcode. The core logic used by the app is split out into the `DotBuddyCore` Swift package (`Package.swift`), which can be built and tested from the command line:

```bash
swift build
swift test
```

`.swiftlint.yml` configures SwiftLint if you have it installed:

```bash
swiftlint
```

## Commit messages and pull requests

This repo uses [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:`, etc.). Pull requests are squash-merged, and the **PR title** becomes the commit on `main` — so PR titles must follow this format. This is enforced automatically by the "Conventional Commits" check.

Direct pushes to `main` are allowed but must also use a Conventional Commits-formatted commit message (validated by the same check).

## Opening a pull request

1. Fork the repo and create a branch off `main`.
2. Make your changes.
3. Open a pull request with a Conventional Commits-formatted title.
4. Wait for CI to pass — required checks must be green before merge.

## Reporting issues

Use [GitHub Issues](../../issues) for bugs and feature requests.
