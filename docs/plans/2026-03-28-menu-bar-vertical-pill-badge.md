# Menu Bar Vertical Pill Badge Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce the menu bar badge width by stacking the quota window label above the remaining percentage.

**Architecture:** Keep the existing custom AppKit image rendering path and palette selection in `MenuBarIconView`, but redraw the pill with a narrower frame and centered two-line text layout. Reuse the current window rotation and threshold logic unchanged.

**Tech Stack:** Swift, SwiftUI, AppKit image drawing, Xcode Release build verification

---

### Task 1: Tighten the custom menu bar badge layout

**Files:**
- Modify: `codexBar/codexBarApp.swift`

**Step 1: Reduce the badge width**

Shrink the rendered image and pill frame so the menu bar label consumes less horizontal space.

**Step 2: Stack label and value vertically**

Replace the horizontal `5H 31%` layout with centered top/bottom text blocks.

**Step 3: Keep text legible**

Use a smaller label font and a bolder percentage font while preserving centered alignment.

### Task 2: Verify and repackage

**Files:**
- Modify: none

**Step 1: Build the Release app without signing**

Run: `xcodebuild -project codexBar.xcodeproj -scheme codexBar -sdk macosx -configuration Release CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CONFIGURATION_BUILD_DIR=/Users/csc/IdeaProjects/codexbar/build-release build`

Expected: build succeeds with exit code `0`.

**Step 2: Refresh the unsigned app artifacts**

Update `dist/Codex Bar.app` and `dist/Codex-Bar-unsigned-Release.zip` from the latest Release build.
