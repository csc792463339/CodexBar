# Menu Bar Glass UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Upgrade the menu bar panel to a premium glass-style interface without changing any account-management behavior.

**Architecture:** Keep the current `MenuBarExtra` structure and business logic intact, but refactor the visible SwiftUI layout into clearer visual sections. Centralize surface, badge, button, and progress styling in a small theme helper so `MenuBarView` and `AccountRowView` share the same design language.

**Tech Stack:** SwiftUI, Swift, macOS system materials, Xcode build verification

---

### Task 1: Add shared glass styling primitives

**Files:**
- Create: `codexBar/Views/MenuBarTheme.swift`

**Step 1: Define surface helpers**

Add color and gradient helpers for:
- panel background
- summary card background
- section background
- active and inactive row backgrounds
- health state colors

**Step 2: Define reusable UI styles**

Add reusable SwiftUI helpers for:
- circular icon buttons
- pill badges
- capsule quota bars
- subtle card border overlays

**Step 3: Keep the API small**

Expose only the styling primitives needed by `MenuBarView` and `AccountRowView` so the theme file stays easy to maintain.

### Task 2: Reshape the main panel into visual sections

**Files:**
- Modify: `codexBar/Views/MenuBarView.swift`
- Modify: `codexBar/Localization.swift`

**Step 1: Replace the flat header with a summary card**

Promote the title, account availability, and refresh action into a clearer top summary section with premium spacing and material treatment.

**Step 2: Restyle grouped account sections**

Wrap each email group in a glass section container and tune scroll spacing, empty state layout, and transient feedback strips to match the new hierarchy.

**Step 3: Restyle the bottom dock**

Convert the current footer controls into consistent icon-based actions while preserving the same behaviors and localized labels.

### Task 3: Rebuild each account row as a glass card

**Files:**
- Modify: `codexBar/Views/AccountRowView.swift`

**Step 1: Reorganize row content**

Promote organization name, plan badge, and status into a stronger primary line and keep quota details readable without table-like clutter.

**Step 2: Update button hierarchy**

Keep switch as the primary action, keep reauth prominent when needed, and convert refresh and delete to secondary icon actions.

**Step 3: Replace raw progress styling**

Use shared capsule quota bars and calmer color handling so the row feels polished in both light and dark mode.

### Task 4: Verify the redesign builds and behaves correctly

**Files:**
- Verify: `codexBar.xcodeproj`

**Step 1: Run build verification**

Run: `xcodebuild -project codexBar.xcodeproj -scheme codexBar -sdk macosx -configuration Debug build`

Expected: build succeeds with exit code `0`.

**Step 2: Launch the app for visual inspection**

Run the app and confirm:
- the panel opens at the expected width
- empty and populated states render correctly
- primary and secondary buttons remain clickable
- success and error banners remain readable
- the panel looks coherent in light and dark appearance
