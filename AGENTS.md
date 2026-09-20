# AGENTS.md

## Project overview

DotBuddy is a native macOS SwiftUI app for managing shell aliases and environment variable files through a visual interface. The reusable file-parsing/editing logic lives in a separate `DotBuddyCore` Swift package; the app itself is an Xcode project.

## Setup

Requires Xcode with the macOS 14 SDK. No external package dependencies.

## Build / Run

```bash
xcodebuild -project DotBuddy.xcodeproj -scheme DotBuddy build   # full app
swift build                                                      # DotBuddyCore package only
```

Releases are built via `.github/workflows/release.yml` on `macos-14` runners, triggered by pushing a `v*` tag.

## Test

```bash
swift test
```

Runs the XCTest suite in `Tests/` (`AliasFileManagerTests.swift`, `EnvFileManagerTests.swift`) against `DotBuddyCore`. The full app UI is not covered by automated tests.

## Lint / Format

```bash
swiftlint
```

Configured via `.swiftlint.yml`.

## Repository structure

- `DotBuddy/` — SwiftUI app source (views, view models, file managers for aliases and env vars)
- `DotBuddy.xcodeproj` — Xcode project for the app
- `Package.swift` + `Tests/` — the `DotBuddyCore` SPM package (parsing/file logic) and its XCTest suite
- `screenshots/` — README screenshots

## Commit and PR conventions

- Commit messages and PR titles must follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `ci:`, `build:`, `perf:`, `style:`, `revert:`), optionally with a scope, e.g. `fix(api): handle null response`.
- This repo squash-merges pull requests only; the PR title becomes the final commit message on `main`.
- A "Conventional Commits" CI check enforces this on both PR titles and direct-push commit messages.
- Branch protection on `main`: no force-pushes, no branch deletion, required status checks must pass.
