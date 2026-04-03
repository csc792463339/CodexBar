# Menu Bar Pill Badge Design

**Goal:** Refine the menu bar quota icon into a smaller flat pill badge that shows the active window label and remaining balance in the format `5H 31%`.

**Current Context:** The menu bar label is rendered by `MenuBarIconView` in `codexBar/codexBarApp.swift`. The previous iteration switched from plain text to a battery-like custom image, but the latest feedback prefers a flatter, smaller rounded tag with no right-side battery nub.

**User Intent:** The badge should:
- remove the right-side protruding cap
- shrink slightly overall
- show the window label to the left of the number, such as `5H 31%` or `7D 97%`
- keep the existing color semantics: green for healthy, yellow for warning, red for exhausted
- keep rotating between real windows only; if no `5H` exists, show only `7D`

**Design:**
- Render the menu bar badge as a single compact rounded rectangle image instead of a battery silhouette.
- Use a darker tinted pill background with a bright semantic border.
- Split the text into two zones:
  - left label: `5H` or `7D`
  - right value: remaining percentage, e.g. `31%`
- Keep the label slightly softer than the value so the percentage remains the focal point.

**Sizing and Layout:**
- Reduce the rendered image height from the previous badge so the pill feels tighter in the menu bar.
- Keep width fixed so rotation between `5H` and `7D` does not change menu bar width.
- Use a monospaced numeric font for the percentage to reduce jitter.

**Fallbacks:**
- If there is no active account or visible quota window, render a muted placeholder pill instead of an empty string.
- Help text should still expose the full current account + window context on hover.

**Testing:**
- Build the app after the badge change.
- Repackage the unsigned Release app so the latest menu bar badge can be tested directly.
