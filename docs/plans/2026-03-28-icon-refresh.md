# App Icon Refresh Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the current app icon with a simplified, higher-fidelity version based on the approved cloud-terminal-usage concept.

**Architecture:** Use `codexBar/Assets/logo.svg` as the single editable master asset, then export the required PNG sizes into `codexBar/Assets.xcassets/AppIcon.appiconset`. Keep the asset catalog manifest unchanged so Xcode continues to resolve the same filenames.

**Tech Stack:** SVG, macOS Quick Look thumbnail rendering, `sips`, Xcode asset catalogs

---

### Task 1: Rebuild the vector master icon

**Files:**
- Modify: `codexBar/Assets/logo.svg`

**Step 1: Replace the old minimal mark**

Redraw the logo as:
- a rounded light tile
- a bold cloud silhouette
- a white terminal prompt
- a cyan usage bar chart
- an integrated upward arrow

**Step 2: Tune for small-size legibility**

Reduce decorative detail, increase contrast, and keep important shapes large enough to survive downsampling.

### Task 2: Export the app icon PNG set

**Files:**
- Modify: `codexBar/Assets.xcassets/AppIcon.appiconset/icon_16.png`
- Modify: `codexBar/Assets.xcassets/AppIcon.appiconset/icon_32.png`
- Modify: `codexBar/Assets.xcassets/AppIcon.appiconset/icon_64.png`
- Modify: `codexBar/Assets.xcassets/AppIcon.appiconset/icon_128.png`
- Modify: `codexBar/Assets.xcassets/AppIcon.appiconset/icon_256.png`
- Modify: `codexBar/Assets.xcassets/AppIcon.appiconset/icon_512.png`
- Modify: `codexBar/Assets.xcassets/AppIcon.appiconset/icon_1024.png`

**Step 1: Render the SVG at master size**

Run a render step that produces a `1024x1024` PNG from `codexBar/Assets/logo.svg`.

**Step 2: Downscale to catalog sizes**

Generate the remaining PNGs with exact square dimensions required by the asset catalog.

**Step 3: Check output dimensions**

Verify each generated file reports the expected pixel size.

### Task 3: Verify integration

**Files:**
- Verify: `codexBar.xcodeproj`

**Step 1: Build the app**

Run: `xcodebuild -project codexBar.xcodeproj -scheme codexBar -sdk macosx -configuration Debug build`

Expected: build succeeds with exit code `0`.

**Step 2: Spot-check icon clarity**

Inspect representative outputs:
- `icon_16.png`
- `icon_32.png`
- `icon_128.png`
- `icon_1024.png`

Expected: the cloud, prompt, chart, and arrow remain readable at each size.
