# Windows 11 Codex Tool Design

## Current Repository Analysis

### Product Shape Today

The current repository implements a macOS menu bar utility for managing multiple Codex/OpenAI ChatGPT OAuth accounts. The existing app is a SwiftUI `MenuBarExtra` that combines account storage, OAuth login, quota refresh, active-account switching, import/export, auto-switching, notifications, and a compact menu bar status badge.

### Files That Contain the Real Product Logic

- `codexBar/Models/TokenAccount.swift`
  - Defines the account model, quota-window representation, sorting rules, usage-state calculation, reset summaries, and auto-switch candidate metrics.
- `codexBar/Services/TokenStore.swift`
  - Persists account state into `~/.codex/token_pool.json` and writes the active account into `~/.codex/auth.json`.
- `codexBar/Services/OAuthManager.swift`
  - Implements OpenAI OAuth PKCE flow, browser launch, localhost callback handling, token exchange, and clipboard-based authorization-link copying.
- `codexBar/Services/AccountBuilder.swift`
  - Decodes JWT claims and builds `TokenAccount` instances from OAuth tokens.
- `codexBar/Services/WhamService.swift`
  - Calls the ChatGPT backend usage APIs and maps the responses into the app’s 5H / 7D quota model.
- `codexBar/Views/MenuBarView.swift`
  - Orchestrates refresh cadence, auto-switching behavior, import/export, reauthorization, user feedback, and force-quit / relaunch prompts for the target Codex app.

### Files That Are Strongly macOS-Specific

- `codexBar/codexBarApp.swift`
- `codexBar/Views/MenuBarView.swift`
- `codexBar/Views/AccountRowView.swift`
- `codexBar/Views/MenuBarTheme.swift`
- `codexBar/Services/GlobalHotKeyManager.swift`
- `codexBar/Services/AuthSwitcher.swift`

These files depend on `SwiftUI`, `AppKit`, `Carbon`, `NSWorkspace`, `NSRunningApplication`, `NSSavePanel`, `NSOpenPanel`, and `MenuBarExtra`. They cannot be reused directly in a Windows build.

### Migration Conclusion

This repository is not a direct cross-platform port candidate. The reusable value is the product behavior and business rules, not the existing UI or platform shell. A Windows version should therefore be implemented as a fully independent top-level project that reproduces the proven behavior while replacing the macOS-only integration points with Windows-native ones.

## Product Goal

Build a Windows 11 desktop utility that preserves the current repository’s functional scope:

- system tray quick access
- independent management window
- multi-account storage
- OpenAI OAuth account onboarding
- browser callback and clipboard-based authorization-link flows
- quota refresh for 5H / 7D windows
- active-account switching through `~/.codex/auth.json`
- account import/export
- automatic account switching when thresholds are hit
- notifications, global hotkey, and target-program restart assistance
- support for both Codex CLI and Codex desktop usage on Windows

## Explicit Constraints

- Windows project must live in a new top-level folder and remain fully independent from the existing macOS project.
- The macOS Swift project remains intact and is not refactored into a shared cross-language core.
- Windows 11 is the target operating system.
- First Windows release is feature-complete relative to the current repository behavior.
- OAuth must support both:
  - browser + localhost callback
  - copy authorization link fallback

## Recommended Windows Architecture

### Selected Direction

Use a Windows-native .NET solution with:

- `C#`
- `WPF`
- a single-process resident app
- system tray integration
- a management window
- internal separation into `App`, `Core`, and `Infrastructure` projects

### Why This Direction

- The product’s hard problems are Windows integration problems, not advanced front-end rendering problems.
- WPF handles tray workflows, notifications, single-instance behavior, file-system access, process inspection, and global hotkeys more pragmatically than WinUI 3 for a first full-featured release.
- A single resident process avoids IPC complexity while still supporting both tray and management-window UX.

## Repository Layout

```text
/
  macos/
    CodexBar.Mac/
      ...existing Swift project moved here or preserved as-is during repo reorganization
  windows/
    CodexBar.Windows/
      CodexBar.Windows.sln
      src/
        CodexBar.Windows.App/
        CodexBar.Windows.Core/
        CodexBar.Windows.Infrastructure/
      tests/
        CodexBar.Windows.Core.Tests/
        CodexBar.Windows.IntegrationTests/
```

### Responsibility Split

- `CodexBar.Windows.App`
  - WPF startup
  - tray icon
  - management window
  - view models
  - command wiring
- `CodexBar.Windows.Core`
  - account domain model
  - quota window model
  - status computation
  - sorting
  - auto-switch rules
  - import/export DTOs
- `CodexBar.Windows.Infrastructure`
  - JSON persistence
  - OAuth flow and callback server
  - JWT decoding
  - usage API client
  - clipboard integration
  - notification integration
  - process detection / restart
  - global hotkey integration

## Windows App Behavior

### UX Shape

The Windows app runs as a single-instance resident utility with two presentation surfaces:

- tray experience for fast interaction
- management window for full account administration

Closing the management window hides it instead of terminating the app. Exiting from the tray menu fully stops the process.

### Tray Responsibilities

- show current active-account summary
- show 5H / 7D remaining or used quota summary
- quick refresh
- quick account switching
- open management window
- add account
- quit

### Management Window Responsibilities

- full account list grouped by email
- active-account indication
- organization / account display naming
- quota bars and reset summaries
- token-expired / suspended / exhausted states
- import/export JSON actions
- add account / reauthorize / delete
- manual refresh
- configurable restart behavior for target programs
- settings for hotkey, thresholds, startup, and target discovery

## Data Model Mapping

The Windows domain layer should preserve the current product semantics from `TokenAccount.swift`.

### Entities

- `TokenAccount`
  - email
  - accountId
  - accessToken
  - refreshToken
  - idToken
  - expiresAt
  - planType
  - primaryUsedPercent
  - secondaryUsedPercent
  - primaryResetAt
  - secondaryResetAt
  - hasPrimaryWindow
  - hasSecondaryWindow
  - lastChecked
  - isActive
  - isSuspended
  - tokenExpired
  - organizationName

- `QuotaWindowDisplay`
  - `5H`
  - `7D`
  - used percent
  - remaining percent
  - reset time

- `UsageStatus`
  - ok
  - warning
  - exceeded
  - banned

### Rules to Preserve

- Account sorting logic from `displaySortKey`
- Visibility and prioritization of 5H / 7D windows
- Warning thresholds
- Exhaustion behavior
- Auto-switch thresholds now implemented in `MenuBarView.swift`
- Import deduplication by `accountId`
- `auth.json` as the active-account truth source

## OAuth Design

### Primary Flow

- Generate PKCE verifier and challenge
- Build the authorization URL using the same OpenAI OAuth parameters already used in `OAuthManager.swift`
- Launch the system browser
- Start a localhost callback server on the configured port
- Validate `state`
- Exchange code for tokens
- Decode JWT claims
- Build the account object
- Persist account
- Trigger immediate refresh

### Fallback Flow

- Reuse the same prepared authorization session
- Copy authorization URL to clipboard
- Keep the pending callback listener active when possible
- If listener startup fails, surface a guided manual-complete flow in the UI

### Windows-Specific Requirements

- Port collision handling
- clear browser-launch failure message
- retry without corrupting pending session state
- secure handling of clipboard writes

## Persistence Design

### File Locations

Windows implementation continues to use:

- `%USERPROFILE%\\.codex\\token_pool.json`
- `%USERPROFILE%\\.codex\\auth.json`

This preserves interoperability with existing Codex CLI and desktop behaviors.

### Persistence Rules

- `token_pool.json` stores all managed accounts
- `auth.json` stores the currently active account
- switching an account only succeeds if `auth.json` write succeeds
- import never silently overwrites existing accounts
- malformed JSON is detected and surfaced; it is never silently discarded

## Usage Refresh Design

### API Scope

Windows implementation mirrors the current repository’s API behavior:

- `https://chatgpt.com/backend-api/wham/usage`
- `https://chatgpt.com/backend-api/accounts/check/v4-2023-04-27?...`

### Refresh Behavior

- refresh active account more frequently while the management window is open
- perform periodic background refresh while resident in the tray
- update organization name and quota windows together
- treat HTTP status codes consistently with current behavior:
  - `401` => token expired
  - `402/403` => suspended / forbidden
  - other failures => preserve last known good state

## Auto-Switch Design

### Trigger Conditions

Preserve the current behavior:

- switch away when 5H remaining is less than or equal to 10%
- switch away when 7D remaining is less than or equal to 3%

### Candidate Ordering

Preserve the current semantics:

- prefer highest constrained remaining percentage
- then prefer highest best-available remaining percentage
- then account ID tiebreak

### Side Effects

- write selected account into `auth.json`
- update in-memory active flag
- notify the user
- optionally restart the configured desktop target when allowed by settings

## Target Program Integration

### Supported Targets

- Codex CLI workflows
- Codex desktop workflows on Windows

### Behavior

- For CLI usage, the app writes `auth.json` and notifies the user. It does not force-kill terminals or generic console processes.
- For desktop usage, the app can detect a configured target process and:
  - notify only
  - request restart
  - terminate and relaunch, depending on settings

### Discovery Strategy

- automatic best-effort detection by configured process name / known path
- manual override path in settings
- safe fallback to “change applies on next launch”

## Windows Integration Design

### Required Integration Surfaces

- tray icon + context menu
- single-instance app activation
- global hotkey
- clipboard support
- Windows toast notifications
- startup registration
- file dialogs

### Behavioral Rules

- hotkey registration failure must not block app startup
- second app launch should bring the current instance to front
- notification failures degrade silently after logging
- exiting the management window should not terminate the resident tray app

## Error Handling

### OAuth Errors

- callback port unavailable
- browser launch failed
- invalid state
- token exchange failed
- incomplete token payload

Each error must surface actionable user feedback and must not leave a partially persisted account.

### Storage Errors

- missing files
- invalid JSON
- write denied
- import duplicates

Storage operations should be transactional wherever possible.

### API Errors

- per-account refresh errors do not block the rest of the refresh batch
- API shape changes must be logged with enough context to debug parsing drift

## Testing Strategy

### Core Tests

- account sorting
- usage-status transitions
- quota-window visibility
- auto-switch decisions
- import deduplication

### Infrastructure Tests

- JSON read/write round-trips
- OAuth URL generation
- JWT decoding
- callback parsing
- usage-response parsing

### Integration Tests

- first launch with empty `.codex`
- add-account success path
- switch-account persistence
- refresh and status update
- auto-switch end-to-end behavior
- import/export round-trip

### Manual Verification

- tray startup
- open/close management window
- global hotkey registration
- browser OAuth path
- clipboard OAuth path
- notification path
- desktop-target restart path

## Non-Goals

- No attempt to make Swift code directly compile on Windows.
- No cross-language shared core in this phase.
- No full UI parity with macOS visuals; functional parity is the priority.

## Recommended Delivery Order

1. Create Windows solution and project skeleton
2. Implement core account model and JSON persistence
3. Implement OAuth and callback handling
4. Implement usage refresh and status mapping
5. Implement management window
6. Implement tray shell and resident lifecycle
7. Implement hotkey, notifications, and target restart behavior
8. Add tests and Windows usage docs

## Open Execution Constraint

Implementation should run in a dedicated git worktree before code changes begin. The repository currently has no preconfigured worktree directory, so the worktree location must be chosen before execution starts.
