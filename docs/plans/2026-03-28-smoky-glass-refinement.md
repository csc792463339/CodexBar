# Smoky Glass Refinement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refine the current UI into a slimmer cold-gray smoky-glass panel with stronger email grouping and a much lighter top summary strip.

**Architecture:** Keep the current SwiftUI structure and interaction logic, but retune the visual system and layout hierarchy. First update the shared theme to support a sharper smoky-glass language, then compress the menu bar and summary strip, then rebuild group headers and account cards around clearer vertical structure.

**Tech Stack:** SwiftUI, Swift, macOS MenuBarExtra, Xcode build verification

---

### Task 1: Rebuild the shared theme around the smoky-glass aesthetic

**Files:**
- Modify: `codexBar/Views/MenuBarTheme.swift`

**Step 1: Sharpen the surface geometry**

Reduce panel, section, and row radii and remove the remaining puffy material feel.

**Step 2: Rework the colors**

Switch to cold neutral fills, smoke-blue highlights, graphite text, and thinner glass edges.

**Step 3: Slim shared controls**

Shrink icon buttons, pills, and quota bars so all downstream views inherit a leaner scale.

### Task 2: Compress the menu bar item and top summary strip

**Files:**
- Modify: `codexBar/codexBarApp.swift`
- Modify: `codexBar/Views/MenuBarView.swift`

**Step 1: Keep the compact menu bar status item**

Preserve the stacked metrics layout, but make sure the visual tone matches the new smoky-glass direction.

**Step 2: Collapse the summary card**

Replace the current multi-row summary treatment with a slim overview strip that keeps only essential information.

**Step 3: Reduce oversized badges**

Remove or downplay large top-level pills so the summary strip no longer dominates the panel.

### Task 3: Strengthen email section titles and slim account cards

**Files:**
- Modify: `codexBar/Views/MenuBarView.swift`
- Modify: `codexBar/Views/AccountRowView.swift`

**Step 1: Promote email titles**

Turn each email header into a clear section title with stronger contrast and a subtle supporting label or rule.

**Step 2: Rebuild card proportions**

Reduce padding, card height, and visual bulk so each account reads as a long, elegant strip instead of a fat block.

**Step 3: Flatten the footer**

Compress the bottom action row into a thinner control rail aligned with the slimmer overall design.

### Task 4: Verify the refined UI builds

**Files:**
- Verify: `codexBar.xcodeproj`

**Step 1: Run build verification**

Run: `xcodebuild -project codexBar.xcodeproj -scheme codexBar -sdk macosx -configuration Debug CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`

Expected: build succeeds with exit code `0`.
