# Menu Bar Pill Badge Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the battery-like menu bar badge with a smaller flat pill that shows `5H 31%` or `7D 97%`.

**Architecture:** Keep the current visible-window rotation logic in `MenuBarIconView`, but change the rendered image from a battery silhouette to a flat rounded tag. The tag will still derive its value from the active visible window's remaining percent, so single-window free accounts naturally stay on `7D`.

**Tech Stack:** Swift, SwiftUI, AppKit image drawing, Xcode Release build verification

---

### Task 1: Redesign the rendered badge image

**Files:**
- Modify: `codexBar/codexBarApp.swift`

**Step 1: Remove the battery cap**

Delete the right-side protrusion from the custom image and render a single rounded rectangle only.

**Step 2: Shrink the overall badge**

Reduce the image and pill dimensions so the menu bar badge feels tighter and flatter.

**Step 3: Split the text into label + value**

Render `5H` or `7D` on the left and the remaining value like `31%` on the right.

### Task 2: Keep semantic coloring and placeholder behavior

**Files:**
- Modify: `codexBar/codexBarApp.swift`

**Step 1: Preserve semantic color variants**

Reuse green / amber / red badge palettes for healthy / warning / exhausted windows.

**Step 2: Preserve placeholder rendering**

Keep a muted fallback pill when there is no active account or no visible window.

### Task 3: Verify and repackage

**Files:**
- Modify: none

**Step 1: Build the Release app without signing**

Run: `xcodebuild -project codexBar.xcodeproj -scheme codexBar -sdk macosx -configuration Release CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CONFIGURATION_BUILD_DIR=/Users/csc/IdeaProjects/codexbar/build-release build`

Expected: build succeeds with exit code `0`.

**Step 2: Refresh the unsigned distribution artifacts**

Rebuild `dist/Codex Bar.app` and `dist/Codex-Bar-unsigned-Release.zip` from the new Release output.
