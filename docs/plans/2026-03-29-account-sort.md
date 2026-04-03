# Account Sort Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Change menu account ordering to use remaining quota first, then `5H`, then `7D`, then email name.

**Architecture:** Keep the current grouped email UI and move display ordering rules into `TokenAccount` so `MenuBarView` only consumes a single model-defined sort key. This limits the change surface and avoids coupling the sorting rules to the SwiftUI view layer.

**Tech Stack:** Swift, SwiftUI, Xcode project build

---

### Task 1: Add a model-backed display sort key

**Files:**
- Modify: `codexBar/Models/TokenAccount.swift`

**Step 1: Add remaining-quota helpers**

- Add explicit remaining quota helpers for the `5H` and `7D` windows.
- Return `nil` when a quota window does not exist so missing windows can sort after present ones.

**Step 2: Add a display sort key**

- Add a small comparable sort-key type or equivalent model helper.
- Order by `5H` remaining descending, then `7D` remaining descending, then normalized email ascending, then `accountId` ascending.

### Task 2: Switch the menu list to the model sort key

**Files:**
- Modify: `codexBar/Views/MenuBarView.swift`

**Step 1: Replace the view-local comparator**

- Remove the current active-account and constrained/best-remaining ordering from `displayOrder`.
- Compare accounts via the model-backed sort key instead.

**Step 2: Keep grouped rendering intact**

- Continue using the existing grouped email UI.
- Keep group ordering based on the best account in each group under the new comparator.

### Task 3: Verify behavior

**Files:**
- Modify: none

**Step 1: Build the app**

Run: `xcodebuild -project codexBar.xcodeproj -scheme codexBar -configuration Debug build`

Expected: Build succeeds without introducing new Swift compiler errors.

**Step 2: Review the diff**

Run: `git diff -- codexBar/Models/TokenAccount.swift codexBar/Views/MenuBarView.swift docs/plans/2026-03-29-account-sort-design.md docs/plans/2026-03-29-account-sort.md`

Expected: Diff is limited to the approved sort-key refactor and documentation.
