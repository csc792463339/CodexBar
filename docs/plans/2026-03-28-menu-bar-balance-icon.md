# Menu Bar Balance Icon Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the text menu bar quota indicator with a compact icon badge that shows the current active window's remaining balance.

**Architecture:** Reuse the existing active-window rotation logic from `MenuBarIconView`, but change the rendered label from plain text to a custom SwiftUI badge. The badge will derive its displayed number from `remainingPercent` on the active visible window so `5H` / `7D` availability stays driven by the already-correct quota parsing model.

**Tech Stack:** Swift, SwiftUI, Xcode build verification

---

### Task 1: Redesign the menu bar icon view

**Files:**
- Modify: `codexBar/codexBarApp.swift`

**Step 1: Add a dedicated badge subview**

Create a compact SwiftUI badge view for the menu bar label with a rounded battery-like body and a small right-side cap.

**Step 2: Switch the displayed metric to remaining balance**

Use the current visible window's `remainingPercent` instead of `usedPercent`, rounded to an integer for display.

**Step 3: Preserve single-window and rotating-window behavior**

Keep the existing timer-based rotation, but ensure it only rotates across real visible windows.

### Task 2: Align icon colors and fallbacks

**Files:**
- Modify: `codexBar/codexBarApp.swift`
- Modify: `codexBar/Views/MenuBarTheme.swift` if shared color helpers are needed

**Step 1: Reuse existing semantic status colors**

Map healthy windows to green, warning windows to amber, and exhausted windows to red.

**Step 2: Add an empty-state badge**

Render a muted placeholder when there is no active account or no visible quota window.

### Task 3: Verify the change

**Files:**
- Modify: none

**Step 1: Build the Release app without signing**

Run: `xcodebuild -project codexBar.xcodeproj -scheme codexBar -sdk macosx -configuration Release CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`

Expected: build succeeds with exit code `0`.

**Step 2: Spot-check behavior**

Confirm the badge shows a remaining balance like `97`, rotates only when two real windows exist, and stays fixed on `7D` for single-window free accounts.
