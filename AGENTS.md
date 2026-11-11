# stupid agent

An iOS app for a bring-your-own-model agent that runs on the device: the user sets an OpenAI-compatible server, key
and model, and the agent executes tool calls on the phone against the app's workspace folder. Built on swift pi
(github.com/stephancill/swift-pi), a Swift port of pi.

## Before changing anything

- Read `docs/PLAN.md` for product direction and `docs/IMPLEMENTATION.md` for the current state and decisions.
- Agent behavior (loop, providers, tools) belongs in swift pi, not here: change it in `../swift-pi`, tag a release
  (`vX.Y.Z`), then `swift package update swift-pi` here (raise `from:` when the app needs the new version) and commit
  `Package.resolved`. Chat screen behavior belongs in stupid chatkit (`../stupid-chatkit`), released the same way.

## Project structure

```
Sources/
  StupidAgent/            # SwiftUI screens (iOS only)
    StupidAgent.swift     # @main and AppModel: settings, workspace, sessions, conversation list
    ConversationsView.swift
    AgentChatView.swift   # Chat screen: stupid chatkit's chat, Stop, the file-change alert
    AgentChatAdapter.swift # ChatAdapter: session entries → chat kit messages, sends through the session
    SettingsView.swift    # Bring-your-own-model settings
    SandboxBridge.swift   # Sandbox extensions for other apps' containers (worse_query technique)
    SandboxContainers.swift # Container discovery and grants, as AppContainerAccess; background inode-scan index
    ContainerIndex.swift  # @Observable over the background index, for the Settings progress UI
  StupidAgentCore/        # No UI; tested with `swift test` on macOS
    ModelSettings.swift   # Provider presets, ModelSettings, SettingsStore, model listing
    Keychain.swift
    ConversationStore.swift
    ChatEntries.swift     # Transcript → chat entries (user, agent response with thinking and tools, notices)
    AppContainers.swift   # AppContainer, AppContainerAccess, container paths and tools
    SQLiteTool.swift      # Read-only SQLite query tool
    AgentSession.swift    # One conversation: the swift pi Agent, file-change approvals, saving
Tests/StupidAgentCoreTests/
```

Keep this section in sync when files are added, moved or renamed.

## Stack and style

- Swift 6, SwiftUI, Observation, iOS 18. Built and run with the `stupid-app` CLI (0.0.27 or later, which resolves
  package dependencies).
- Dependencies are package dependencies pinned in `Package.resolved`:
  - swift pi (`https://github.com/stephancill/swift-pi`)
  - stupid chatkit (`https://github.com/stephancill/stupid-chatkit`), iOS-only through a platform condition so
    `swift test` builds on macOS
- The chat screen is chatkit's: extend it through the adapter, and change chatkit itself in `../stupid-chatkit` (see its
  AGENTS.md). While working on a dependency, point at a local checkout with `.package(path:)`, but never commit that.
- Follow the stupid iOS design rules: native components, no monospaced fonts, at most two font sizes per group,
  centered `.alert` confirmations for destructive actions.
- UI files are wrapped in `#if os(iOS)` so `swift test` can build the package on macOS.
- Prefer failing loudly over fallbacks. The one deliberate exception is the simulator-only API key storage in
  `SettingsStore` (see `docs/IMPLEMENTATION.md`).
- Named parameters, value types, `@MainActor @Observable` for UI state.

## Build, test, run

- `swift test` runs the core tests.
- `stupid-app build` after source changes; `stupid-app run --simulator` to install. Follow the simulator claim rules in
  the user's global instructions before using a simulator.

## Before committing

- Update `docs/IMPLEMENTATION.md` to describe the current state. Never include personal information: assume it is public.
- Conventional commits (`feat:`, `fix:`, `chore:`, ...).
