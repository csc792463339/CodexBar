# Force Quit Codex On Switch Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a post-switch prompt that can force-quit Codex.app so account changes apply immediately.

**Architecture:** Keep the existing account activation path in `MenuBarView`, then branch after a successful `store.activate(...)`. If `Codex.app` is running, present an `NSAlert` and route the user's choice into the existing `forceQuitCodex` helper; otherwise, show a lightweight success message inside the menu UI.

**Tech Stack:** SwiftUI, AppKit, macOS menu bar app APIs

---

### Task 1: Hook account switching into the existing force-quit flow

**Files:**
- Modify: `codexBar/Views/MenuBarView.swift`
- Modify: `codexBar/Localization.swift`
- Verify: `codexBar.xcodeproj`

**Step 1: Add localized success strings**

Add short bilingual strings for:
- switch applied on next launch
- switch completed with force quit
- switch completed with reopen

**Step 2: Detect whether Codex.app is running after `store.activate(...)`**

Use `NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex")` and keep the new behavior limited to manual switching from the menu.

**Step 3: Present a restart alert only when Codex.app is running**

Reuse the existing restart-related localized strings and map the three buttons to:
- force quit and reopen
- force quit only
- later

**Step 4: Surface a success message in the menu**

Set `showSuccess` so the user still gets feedback when:
- Codex.app is not running
- the user chooses later
- the user chooses one of the force-quit options

**Step 5: Verify by building**

Run:

```bash
xcodebuild -project codexBar.xcodeproj -scheme codexBar -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Expected: `BUILD SUCCEEDED`
