# Menu Bar Vertical Pill Badge Design

**Goal:** Make the menu bar quota badge narrower by stacking the window label above the remaining percentage inside a compact rounded pill.

**Current Context:** The menu bar badge is currently a horizontal pill rendered as an AppKit image in `codexBar/codexBarApp.swift`. The latest user feedback wants the badge width reduced further without losing clarity.

**User Intent:** The badge should:
- keep the current rounded pill style
- reduce horizontal width
- render `7D` or `5H` on the first line
- render the remaining percentage such as `22%` on the second line
- keep the existing green / yellow / red threshold logic

**Design:**
- Preserve the fixed-width custom image approach so the menu bar does not depend on SwiftUI background rendering behavior.
- Change the internal layout from horizontal text zones to a centered two-line stack.
- Make the badge slightly taller and noticeably narrower than the current horizontal pill.
- Keep the label line lighter/smaller and the percentage line bolder/larger.

**Visual Direction:**
- Flat rounded pill with tight padding and centered text.
- Semantic border and text colors remain unchanged.
- Subtle background gradient is acceptable, but the shape should read as a compact tag rather than a battery.

**Testing:**
- Build the unsigned Release app.
- Refresh `dist/` artifacts so the new narrower vertical pill can be tested directly.
