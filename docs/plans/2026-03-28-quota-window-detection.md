# Quota Window Detection Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Parse quota windows by duration instead of response key name, render only real windows, and display the next refresh time in the UI.

**Architecture:** Keep the existing persisted account schema so saved account data stays compatible, but reinterpret the stored slots as app-level `5H` and `7D` windows. Add small model helpers for visible windows and refresh labels, update the API parser to classify windows by `limit_window_seconds`, and switch the UI to render dynamic visible windows instead of fixed placeholders.

**Tech Stack:** Swift, SwiftUI, Foundation, Xcode build verification

---

### Task 1: Correct the API window classification

**Files:**
- Modify: `codexBar/Services/WhamService.swift`

**Step 1: Extract a reusable window parser**

Add a helper that reads a rate-limit window dictionary and returns the window duration, used percent, and reset date.

**Step 2: Classify windows by duration**

Map `18000` seconds to the app's `5H` slot and `604800` seconds to the app's `7D` slot, regardless of whether the response key is `primary_window` or `secondary_window`.

**Step 3: Ignore unknown windows safely**

Skip unsupported durations rather than guessing, so future response changes do not silently corrupt the UI.

### Task 2: Add model helpers for visible quota windows

**Files:**
- Modify: `codexBar/Models/TokenAccount.swift`
- Modify: `codexBar/Localization.swift`

**Step 1: Add a lightweight visible-window model**

Add a computed representation for actual visible quota windows with label, percent used, reset date, countdown text, and absolute next-refresh text.

**Step 2: Centralize remaining-quota helpers**

Add helpers for effective remaining quota and existing visible windows so sorting and auto-switch logic can work for single-window accounts.

**Step 3: Add localized next-refresh copy**

Add string helpers for absolute next-refresh display and any fallback labels needed for windows with no upcoming reset.

### Task 3: Update the account card and summary UI

**Files:**
- Modify: `codexBar/Views/AccountRowView.swift`
- Modify: `codexBar/Views/MenuBarView.swift`

**Step 1: Render only visible quota cards**

Replace the fixed `5H` / `7D` card row with a `ForEach` over the account's visible windows.

**Step 2: Show the next refresh time**

Display the absolute next-refresh time in each visible quota card and add a concise active-account summary line for the currently selected account.

**Step 3: Keep warning and exhausted banners correct**

Update any banner text that currently assumes `primary` means `5H`, so single-window `7D` accounts show accurate messaging.

### Task 4: Update menu bar behavior that assumed fixed windows

**Files:**
- Modify: `codexBar/codexBarApp.swift`
- Modify: `codexBar/Views/MenuBarView.swift`

**Step 1: Fix the rotating menu bar metric**

Rotate through only the active account's real visible windows; if there is one window, show only that one.

**Step 2: Fix sorting and auto-switch helpers**

Use the best available real remaining quota rather than blindly prioritizing `primaryUsedPercent`.

### Task 5: Verify the change

**Files:**
- Modify: none

**Step 1: Build the app**

Run: `xcodebuild -project codexBar.xcodeproj -scheme codexBar -sdk macosx -configuration Debug build`

Expected: build succeeds with exit code `0`.

**Step 2: Re-check a live free-account response**

Use the existing local auth state to confirm that the real `free` account now maps to a single visible `7D` window with a next-refresh time.
