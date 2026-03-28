# Transparent Compact UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the menu bar metrics compact and reshape the dropdown into a wider, cleaner, fully transparent glass panel with smaller controls.

**Architecture:** Reuse the current SwiftUI structure but tighten proportions everywhere. Update the shared theme primitives first so the transparency and sizing changes propagate consistently, then adjust the menu bar label view and the dropdown layout to fit the revised visual system.

**Tech Stack:** SwiftUI, Swift, macOS MenuBarExtra, Xcode build verification

---

### Task 1: Update shared styling primitives for the new crystal-glass direction

**Files:**
- Modify: `codexBar/Views/MenuBarTheme.swift`

**Step 1: Widen the panel**

Change the shared panel width to `440` and reduce panel, section, and row radii to match the smaller component scale.

**Step 2: Remove milky fills**

Replace the current material-heavy fills with more transparent fills, lighter strokes, and restrained shadows so the panel reads as clear glass instead of frosted white.

**Step 3: Shrink shared control styles**

Reduce the default icon button, pill badge, and quota bar sizing so the rest of the UI can become denser without losing hierarchy.

### Task 2: Compact the menu bar status item

**Files:**
- Modify: `codexBar/codexBarApp.swift`

**Step 1: Remove the oversized leading icon**

Replace the current symbolic icon with a small status dot or short marker tied to account health.

**Step 2: Stack the quota text vertically**

Render the 5-hour and 7-day metrics as two short lines instead of one horizontal string so the menu bar item stays narrow.

**Step 3: Keep degraded states readable**

When a quota is exhausted, keep the two-line layout and use color/short labels rather than long phrases that widen the item.

### Task 3: Rebalance the dropdown layout and typography

**Files:**
- Modify: `codexBar/Views/MenuBarView.swift`
- Modify: `codexBar/Views/AccountRowView.swift`

**Step 1: Tighten the summary card**

Reduce icon treatment, padding, badge sizes, and top-card height so the summary no longer dominates the panel.

**Step 2: Tighten the list and footer**

Reduce section paddings, row spacings, and footer control sizes so more useful content fits on screen.

**Step 3: Improve text contrast**

Use more stable primary and secondary text colors against the transparent glass backgrounds and reduce the washed-out feel from the current palette.

### Task 4: Verify the refined UI build

**Files:**
- Verify: `codexBar.xcodeproj`

**Step 1: Run build verification**

Run: `xcodebuild -project codexBar.xcodeproj -scheme codexBar -sdk macosx -configuration Debug CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`

Expected: build succeeds with exit code `0`.
