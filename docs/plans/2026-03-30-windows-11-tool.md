# Windows 11 Codex Tool Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Windows 11 tray + management-window Codex account tool that reproduces the current repository’s account storage, OAuth, quota refresh, switching, auto-switch, import/export, notification, and hotkey behaviors for both Codex CLI and desktop workflows.

**Architecture:** Create a fully independent top-level Windows solution under `windows/` using WPF plus separate `App`, `Core`, and `Infrastructure` projects. Reproduce the existing repository’s business rules in a .NET domain layer, then connect that logic to Windows-native system tray, notifications, global hotkeys, persistence, OAuth callback hosting, and target-process management.

**Tech Stack:** C#, .NET, WPF, xUnit or NUnit, Windows tray integration, localhost HTTP listener, JSON serialization, Windows toast notifications

---

### Task 1: Reorganize Repository Layout For Independent Windows Work

**Files:**
- Create: `windows/CodexBar.Windows/`
- Create: `windows/CodexBar.Windows/CodexBar.Windows.sln`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.App/`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Core/`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/`
- Create: `windows/CodexBar.Windows/tests/CodexBar.Windows.Core.Tests/`
- Create: `windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests/`
- Modify: `.gitignore`

**Step 1: Write the failing structure expectation**

Document a repository expectation check in `windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests/RepositoryLayoutTests.cs` that asserts the Windows solution and project directories exist.

```csharp
[Fact]
public void WindowsSolutionLayoutExists()
{
    Assert.True(Directory.Exists(Path.Combine(Root, "windows", "CodexBar.Windows", "src", "CodexBar.Windows.App")));
    Assert.True(Directory.Exists(Path.Combine(Root, "windows", "CodexBar.Windows", "src", "CodexBar.Windows.Core")));
    Assert.True(Directory.Exists(Path.Combine(Root, "windows", "CodexBar.Windows", "src", "CodexBar.Windows.Infrastructure")));
}
```

**Step 2: Run test to verify it fails**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests`

Expected: FAIL because the Windows solution and test project do not exist yet.

**Step 3: Create the minimal solution skeleton**

Create the solution, the three source projects, the two test projects, and update `.gitignore` for Windows build outputs and local worktree directories if needed.

**Step 4: Run test to verify it passes**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests`

Expected: PASS for the repository layout test.

**Step 5: Commit**

```bash
git add .gitignore windows/CodexBar.Windows
git commit -m "chore: scaffold independent windows solution"
```

### Task 2: Port The Core Account Domain Model

**Files:**
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Core/Models/TokenAccount.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Core/Models/QuotaWindowDisplay.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Core/Models/UsageStatus.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Core/Models/AccountDisplaySortKey.cs`
- Test: `windows/CodexBar.Windows/tests/CodexBar.Windows.Core.Tests/TokenAccountTests.cs`

**Step 1: Write the failing tests**

Write tests for:

- visible quota window selection
- remaining percentage calculation
- usage status calculation
- exhausted window preference
- next refresh summary formatting boundary behavior

```csharp
[Fact]
public void UsageStatus_IsExceeded_WhenAnyVisibleWindowHits100()
{
    var account = new TokenAccount { HasPrimaryWindow = true, PrimaryUsedPercent = 100 };
    Assert.Equal(UsageStatus.Exceeded, account.UsageStatus);
}
```

**Step 2: Run test to verify it fails**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.Core.Tests --filter TokenAccountTests`

Expected: FAIL because the model types do not exist yet.

**Step 3: Write the minimal implementation**

Implement the domain model to preserve the semantics from `codexBar/Models/TokenAccount.swift`, including:

- 5H / 7D windows
- remaining percentages
- most-constrained and best-available percentages
- exhausted window preference
- usage status states

**Step 4: Run test to verify it passes**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.Core.Tests --filter TokenAccountTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add windows/CodexBar.Windows/src/CodexBar.Windows.Core windows/CodexBar.Windows/tests/CodexBar.Windows.Core.Tests
git commit -m "feat: port windows account domain model"
```

### Task 3: Port Sorting And Auto-Switch Decision Logic

**Files:**
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Core/Services/AccountOrderingService.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Core/Services/AutoSwitchService.cs`
- Test: `windows/CodexBar.Windows/tests/CodexBar.Windows.Core.Tests/AccountOrderingServiceTests.cs`
- Test: `windows/CodexBar.Windows/tests/CodexBar.Windows.Core.Tests/AutoSwitchServiceTests.cs`

**Step 1: Write the failing tests**

Cover:

- sort order by primary remaining percentage
- fallback to secondary window
- tie-break by normalized email and account ID
- auto-switch trigger at 10% 5H and 3% 7D remaining
- best candidate selection

```csharp
[Fact]
public void AutoSwitch_SelectsCandidateWithHighestMostConstrainedRemaining()
{
    var active = Fixtures.ActiveAccount(primaryRemaining: 8, secondaryRemaining: 50);
    var best = Fixtures.Candidate(primaryRemaining: 60, secondaryRemaining: 40);
    var next = service.ChooseReplacement(active, new[] { best });
    Assert.Equal(best.AccountId, next!.AccountId);
}
```

**Step 2: Run test to verify it fails**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.Core.Tests --filter "AccountOrderingServiceTests|AutoSwitchServiceTests"`

Expected: FAIL because the services do not exist yet.

**Step 3: Write the minimal implementation**

Implement the exact ordering and selection semantics from:

- `displaySortKey`
- `mostConstrainedRemainingPercent`
- `bestAvailableRemainingPercent`
- `autoSwitchIfNeeded`

**Step 4: Run test to verify it passes**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.Core.Tests --filter "AccountOrderingServiceTests|AutoSwitchServiceTests"`

Expected: PASS.

**Step 5: Commit**

```bash
git add windows/CodexBar.Windows/src/CodexBar.Windows.Core windows/CodexBar.Windows/tests/CodexBar.Windows.Core.Tests
git commit -m "feat: add windows sorting and auto-switch rules"
```

### Task 4: Implement Codex File Persistence

**Files:**
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Persistence/CodexPathProvider.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Persistence/TokenPoolStore.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Persistence/AuthFileWriter.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Persistence/AccountImportSummary.cs`
- Test: `windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests/PersistenceTests.cs`

**Step 1: Write the failing tests**

Write tests for:

- missing `.codex` directory initialization
- token pool save/load round-trip
- auth file active-account write
- import duplicate skipping
- invalid JSON rejection

```csharp
[Fact]
public async Task Activate_WritesAuthJsonWithSelectedAccountId()
{
    await store.ActivateAsync(account);
    var json = await File.ReadAllTextAsync(authPath);
    Assert.Contains(account.AccountId, json);
}
```

**Step 2: Run test to verify it fails**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter PersistenceTests`

Expected: FAIL because the persistence layer does not exist.

**Step 3: Write the minimal implementation**

Implement:

- `%USERPROFILE%\\.codex` resolution
- `token_pool.json` read/write
- `auth.json` write
- active-account detection from `auth.json`
- import/export transactional behavior

**Step 4: Run test to verify it passes**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter PersistenceTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests
git commit -m "feat: add windows codex persistence layer"
```

### Task 5: Implement JWT Decoding And Account Building

**Files:**
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Auth/JwtDecoder.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Auth/AccountBuilder.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Auth/OAuthTokens.cs`
- Test: `windows/CodexBar.Windows/tests/CodexBar.Windows.Core.Tests/AccountBuilderTests.cs`

**Step 1: Write the failing tests**

Cover:

- valid JWT payload decoding
- missing claim fallback behavior
- account ID extraction from access token
- email extraction from ID token
- expiration parsing

**Step 2: Run test to verify it fails**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.Core.Tests --filter AccountBuilderTests`

Expected: FAIL because auth helper classes do not exist.

**Step 3: Write the minimal implementation**

Port the claim-decoding behavior from `codexBar/Services/AccountBuilder.swift`, including:

- base64url decoding without signature validation
- `chatgpt_account_id` extraction
- `chatgpt_plan_type` extraction
- email extraction
- token expiration mapping

**Step 4: Run test to verify it passes**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.Core.Tests --filter AccountBuilderTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure windows/CodexBar.Windows/tests/CodexBar.Windows.Core.Tests
git commit -m "feat: add windows jwt account builder"
```

### Task 6: Implement OAuth Session Preparation And Callback Handling

**Files:**
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Auth/OAuthSession.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Auth/OAuthClient.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Auth/LocalCallbackServer.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Auth/OAuthErrors.cs`
- Test: `windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests/OAuthClientTests.cs`

**Step 1: Write the failing tests**

Cover:

- authorization URL generation with PKCE and state
- state mismatch rejection
- callback request parsing
- token exchange payload generation
- link-copy fallback session creation

```csharp
[Fact]
public void PrepareAuthorizationSession_IncludesCodeChallengeAndState()
{
    var session = client.PrepareSession();
    Assert.Contains("code_challenge=", session.AuthorizationUrl);
    Assert.Contains("state=", session.AuthorizationUrl);
}
```

**Step 2: Run test to verify it fails**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter OAuthClientTests`

Expected: FAIL because OAuth classes do not exist.

**Step 3: Write the minimal implementation**

Implement:

- PKCE generation
- OpenAI authorization URL creation
- localhost callback listener
- token exchange request
- clipboard-link fallback entry point

**Step 4: Run test to verify it passes**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter OAuthClientTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests
git commit -m "feat: add windows oauth flow infrastructure"
```

### Task 7: Implement Usage API Client And Response Parsing

**Files:**
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Usage/WhamApiClient.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Usage/UsageParser.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Usage/WhamUsageResult.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Usage/WhamErrors.cs`
- Test: `windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests/UsageParserTests.cs`

**Step 1: Write the failing tests**

Cover:

- mapping 18,000-second window to 5H
- mapping 604,800-second window to 7D
- missing window handling
- 401 / 402 / 403 response handling
- plan type parsing

**Step 2: Run test to verify it fails**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter UsageParserTests`

Expected: FAIL because the usage parser and API client do not exist.

**Step 3: Write the minimal implementation**

Port the current API interaction and parsing semantics from `WhamService.swift`.

**Step 4: Run test to verify it passes**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter UsageParserTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests
git commit -m "feat: add windows usage refresh client"
```

### Task 8: Build The Application State Orchestrator

**Files:**
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.App/Services/AccountStateService.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.App/Services/RefreshScheduler.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.App/Services/ActiveAccountCoordinator.cs`
- Test: `windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests/AccountStateServiceTests.cs`

**Step 1: Write the failing tests**

Cover:

- startup restores active account from auth file
- add account triggers immediate refresh
- activate account updates in-memory and persisted state
- background refresh preserves old data on failure
- auto-switch triggers when thresholds are crossed

**Step 2: Run test to verify it fails**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter AccountStateServiceTests`

Expected: FAIL because the app orchestration services do not exist.

**Step 3: Write the minimal implementation**

Implement the application-facing orchestration layer that coordinates:

- persistence
- OAuth
- refresh scheduling
- active account marking
- auto-switch invocation

**Step 4: Run test to verify it passes**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter AccountStateServiceTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add windows/CodexBar.Windows/src/CodexBar.Windows.App windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests
git commit -m "feat: add windows account state orchestration"
```

### Task 9: Build The Management Window

**Files:**
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.App/ViewModels/ManagerWindowViewModel.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.App/ViewModels/AccountRowViewModel.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.App/Views/ManagerWindow.xaml`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.App/Views/ManagerWindow.xaml.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.App/Styles/Theme.xaml`
- Test: `windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests/ManagerWindowViewModelTests.cs`

**Step 1: Write the failing tests**

Cover:

- grouped account projection
- active-account label projection
- refresh command wiring
- import/export command wiring
- token-expired / suspended / exhausted presentation states

**Step 2: Run test to verify it fails**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter ManagerWindowViewModelTests`

Expected: FAIL because the management window and its view models do not exist.

**Step 3: Write the minimal implementation**

Implement the full management UI with:

- grouped account list
- quota bars
- add / refresh / reauth / delete actions
- import / export
- settings entry point

**Step 4: Run test to verify it passes**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter ManagerWindowViewModelTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add windows/CodexBar.Windows/src/CodexBar.Windows.App windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests
git commit -m "feat: add windows management window"
```

### Task 10: Build The Tray Experience

**Files:**
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.App/Services/TrayIconService.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.App/ViewModels/TrayMenuViewModel.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.App/Resources/Tray/`
- Test: `windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests/TrayMenuViewModelTests.cs`

**Step 1: Write the failing tests**

Cover:

- tray summary projection for active account
- quick switch command population
- open-window command
- refresh command
- quit command wiring

**Step 2: Run test to verify it fails**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter TrayMenuViewModelTests`

Expected: FAIL because tray services do not exist.

**Step 3: Write the minimal implementation**

Implement a resident tray shell that:

- keeps the process alive
- exposes the required context-menu actions
- updates icon text / menu summary from account state
- opens the management window on demand

**Step 4: Run test to verify it passes**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter TrayMenuViewModelTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add windows/CodexBar.Windows/src/CodexBar.Windows.App windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests
git commit -m "feat: add windows tray experience"
```

### Task 11: Add Windows Integration Features

**Files:**
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Windows/GlobalHotKeyService.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Windows/ClipboardService.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Windows/NotificationService.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Windows/SingleInstanceService.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Windows/StartupRegistrationService.cs`
- Test: `windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests/WindowsIntegrationServiceTests.cs`

**Step 1: Write the failing tests**

Cover:

- hotkey registration result handling
- clipboard copy abstraction
- notification payload generation
- single-instance secondary-launch behavior
- startup toggle persistence

**Step 2: Run test to verify it fails**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter WindowsIntegrationServiceTests`

Expected: FAIL because the Windows integration services do not exist.

**Step 3: Write the minimal implementation**

Implement non-blocking Windows integration wrappers that the app can consume safely.

**Step 4: Run test to verify it passes**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter WindowsIntegrationServiceTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests
git commit -m "feat: add windows integration services"
```

### Task 12: Add Desktop Target Detection And Restart Control

**Files:**
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure/Targets/TargetProcessService.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.Core/Models/TargetRestartMode.cs`
- Test: `windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests/TargetProcessServiceTests.cs`

**Step 1: Write the failing tests**

Cover:

- detect configured desktop target
- safe fallback when target path is missing
- restart-mode behavior selection
- CLI-safe behavior that avoids killing arbitrary terminals

**Step 2: Run test to verify it fails**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter TargetProcessServiceTests`

Expected: FAIL because the target-process service does not exist.

**Step 3: Write the minimal implementation**

Implement a service that:

- locates the configured desktop target
- determines whether to notify only, restart, or relaunch
- never force-kills generic CLI processes

**Step 4: Run test to verify it passes**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter TargetProcessServiceTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add windows/CodexBar.Windows/src/CodexBar.Windows.Infrastructure windows/CodexBar.Windows/src/CodexBar.Windows.Core windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests
git commit -m "feat: add windows target process management"
```

### Task 13: Add Import / Export And Settings UX Completion

**Files:**
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.App/ViewModels/SettingsViewModel.cs`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.App/Views/SettingsWindow.xaml`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.App/Views/SettingsWindow.xaml.cs`
- Modify: `windows/CodexBar.Windows/src/CodexBar.Windows.App/ViewModels/ManagerWindowViewModel.cs`
- Test: `windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests/SettingsViewModelTests.cs`

**Step 1: Write the failing tests**

Cover:

- threshold persistence
- desktop target path persistence
- hotkey setting persistence
- restart mode persistence
- import/export command exposure

**Step 2: Run test to verify it fails**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter SettingsViewModelTests`

Expected: FAIL because the settings flow does not exist.

**Step 3: Write the minimal implementation**

Implement the first full settings surface and connect it to the management window.

**Step 4: Run test to verify it passes**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter SettingsViewModelTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add windows/CodexBar.Windows/src/CodexBar.Windows.App windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests
git commit -m "feat: add windows settings and import export flow"
```

### Task 14: Add End-To-End Startup And App Lifecycle Wiring

**Files:**
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.App/App.xaml`
- Create: `windows/CodexBar.Windows/src/CodexBar.Windows.App/App.xaml.cs`
- Modify: `windows/CodexBar.Windows/src/CodexBar.Windows.App/CodexBar.Windows.App.csproj`
- Test: `windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests/AppLifecycleTests.cs`

**Step 1: Write the failing tests**

Cover:

- single-instance startup
- tray initialization
- initial account-state load
- management window activation on second launch

**Step 2: Run test to verify it fails**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter AppLifecycleTests`

Expected: FAIL because the final app lifecycle wiring is incomplete.

**Step 3: Write the minimal implementation**

Wire together the startup sequence so the built app actually launches as a resident Windows utility.

**Step 4: Run test to verify it passes**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter AppLifecycleTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add windows/CodexBar.Windows/src/CodexBar.Windows.App windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests
git commit -m "feat: finalize windows app lifecycle"
```

### Task 15: Add Documentation And Release Verification

**Files:**
- Create: `windows/CodexBar.Windows/README.md`
- Create: `windows/CodexBar.Windows/docs/windows-setup.md`
- Modify: `README.md`

**Step 1: Write the failing documentation check**

Add a simple test or scripted verification that asserts the Windows README and setup guide exist and mention:

- OAuth methods
- `.codex` file locations
- tray behavior
- target restart behavior

**Step 2: Run test to verify it fails**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests --filter Documentation`

Expected: FAIL because the docs do not exist yet.

**Step 3: Write the minimal implementation**

Document:

- build instructions
- runtime requirements
- supported workflows
- known limitations
- Windows packaging / distribution expectations

**Step 4: Run the full verification**

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.Core.Tests`

Run: `dotnet test windows/CodexBar.Windows/tests/CodexBar.Windows.IntegrationTests`

Expected: PASS across all Windows test projects.

**Step 5: Commit**

```bash
git add README.md windows/CodexBar.Windows
git commit -m "docs: add windows tool documentation"
```

## Execution Prerequisite

Before implementing this plan, create a dedicated git worktree for the Windows effort. The repository currently has no `.worktrees/`, no `worktrees/`, and no `CLAUDE.md` worktree preference, so the worktree location must be chosen explicitly.
