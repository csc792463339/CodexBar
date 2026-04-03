# Shortcut OAuth Link Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a fixed `Command+Shift+L` global shortcut that starts the local OAuth callback server, generates a new authorization link, and copies it to the clipboard without opening the browser.

**Architecture:** Refactor `OAuthManager` so OAuth session preparation is shared between browser-driven and clipboard-driven entry points. Add a small Carbon-based hotkey service that invokes the new clipboard entry point at app launch, and route user feedback through published OAuth messages that the menu bar UI already renders.

**Tech Stack:** SwiftUI, AppKit, Carbon, Combine, Foundation

---

### Task 1: Refactor OAuth session preparation

**Files:**
- Modify: `codexBar/Services/OAuthManager.swift`

**Step 1: Extract shared OAuth session setup**

Move PKCE, `state`, authorize URL generation, and callback server startup into a helper that returns the generated URL instead of always opening it immediately.

**Step 2: Preserve existing browser flow**

Update `startOAuth` to call the shared helper, then open the generated URL with `NSWorkspace.shared.open`.

**Step 3: Add clipboard-driven flow**

Add a new public method that prepares a session, writes the URL to `NSPasteboard.general`, and publishes a success message without opening the browser.

### Task 2: Add the global shortcut service

**Files:**
- Create: `codexBar/Services/GlobalHotKeyManager.swift`
- Modify: `codexBar/codexBarApp.swift`

**Step 1: Register the fixed shortcut**

Implement a small Carbon hotkey manager that registers `Command+Shift+L` on launch and calls into `OAuthManager`.

**Step 2: Keep service lifetime stable**

Own the hotkey manager from the app entry point so the registration stays alive for the process lifetime.

### Task 3: Route success and error messages into the UI

**Files:**
- Modify: `codexBar/Views/MenuBarView.swift`
- Modify: `codexBar/Localization.swift`

**Step 1: Add localized copy-success text**

Introduce strings for the shortcut copy success message and, if needed, clipboard or callback-start errors.

**Step 2: Observe OAuth-published messages**

Update the menu bar view to react to success and error messages emitted by `OAuthManager`, while keeping existing local success banners such as refresh and account switch feedback intact.

### Task 4: Verify the app

**Files:**
- Modify: none

**Step 1: Build the macOS target**

Run: `xcodebuild -project codexBar.xcodeproj -scheme codexBar -configuration Debug build`

Expected: build succeeds with the new hotkey service and OAuth refactor.

**Step 2: Sanity-check source wiring**

Run: `rg -n "copyAuthorizationLinkToClipboard|RegisterEventHotKey|commandKey|shiftKey" codexBar -S`

Expected: the new clipboard flow, hotkey registration, and fixed modifiers are all present in the source tree.
