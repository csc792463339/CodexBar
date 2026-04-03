# Menu Bar Balance Icon Design

**Goal:** Replace the current text-based menu bar metric with a compact icon-style badge that shows the active quota window's remaining balance inside the icon.

**Current Context:** The menu bar label is rendered by `MenuBarIconView` in `codexBar/codexBarApp.swift`. It currently displays plain text such as `5h 42%` and rotates between visible windows every 60 seconds.

**User Intent:** The menu bar should look like a small battery / balance icon. The balance number should be displayed inside the icon. When both `5H` and `7D` windows exist, the icon should rotate between them. If the account has no `5H` window, it should only show `7D`.

**Design:**
- Replace the current left status capsule + text layout with a single compact custom badge.
- The badge should visually resemble a battery / quota gauge with a rounded body and a small right-side terminal cap.
- The icon should show the active window's **remaining** percent as an integer, not used percent.
- The visible window source remains the existing `visibleQuotaWindows` list so single-window `7D` accounts naturally skip `5H`.

**Window Rotation Behavior:**
- Keep the current timer-driven rotation behavior.
- When there is only one visible window, the icon stays fixed on that window.
- When there are two visible windows, rotate between them without expanding the menu bar width.

**Visual Direction:**
- Use the existing green / amber / red semantic color logic.
- Render the badge with a tinted border and a filled interior that reflects remaining quota health.
- Keep the number centered and legible at small menu bar sizes.
- Do not place a large external `5H` / `7D` label next to the badge; the icon should remain the primary element.

**Interaction and Fallbacks:**
- If there is no active account or no visible window, render a muted empty badge placeholder.
- Status color should still reflect warning / exhausted / banned states across the active account.

**Testing:**
- Build the app after the icon redesign.
- Verify single-window `7D` accounts show one badge only.
- Verify dual-window accounts rotate without showing fake windows.
