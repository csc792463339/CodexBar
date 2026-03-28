# Account Sorting Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Keep the active account pinned first and sort every other account by remaining quota.

**Architecture:** Reuse the existing grouped menu structure and replace the current status-based comparator with a quota-based comparator. Apply the same comparator to both group ordering and account ordering so the UI stays consistent.

**Tech Stack:** SwiftUI, Swift, Xcode project build verification

---

### Task 1: Replace status-first sorting with quota-first sorting

**Files:**
- Modify: `codexBar/Views/MenuBarView.swift`

**Step 1: Identify the current sort helpers**

Inspect the grouped account builder and current `bestStatus` / `statusRank` helpers in `codexBar/Views/MenuBarView.swift`.

**Step 2: Write the new comparator**

Add helpers that:
- Return remaining 5-hour quota and remaining weekly quota.
- Compare two accounts with this order: active first, 5-hour remaining descending, weekly remaining descending, stable string tie-breakers.

**Step 3: Apply the comparator to groups and rows**

Update the group sort to use the best-ranked account in each email bucket and update the row sort to use the same comparator.

**Step 4: Run build verification**

Run: `xcodebuild -project codexBar.xcodeproj -scheme codexBar -sdk macosx -configuration Debug build`

Expected: build succeeds with exit code `0`.
