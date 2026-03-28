# Menu Bar Glass UI Design

**Goal:** Redesign the menu bar panel with a more premium glassmorphism aesthetic while keeping all existing functionality and account-management flows unchanged.

**Current Context:** The app is a macOS `MenuBarExtra` built with SwiftUI. The current panel structure already has the right information architecture: a top bar, grouped account list, transient success and error strips, and a bottom action row. The visible UI lives primarily in `codexBar/Views/MenuBarView.swift` and `codexBar/Views/AccountRowView.swift`.

**Approved Direction:** Build a system-adaptive glass panel that follows macOS light and dark appearance while maintaining a calm, high-end, semi-transparent feel. Keep motion restrained and prioritize hierarchy, clarity, and material quality over flashy effects.

**Design:**
- Reframe the top area as a summary card instead of a flat title row.
- Keep email-grouped accounts, but render each email group as a distinct section and each account as a raised glass card.
- Preserve the existing bottom actions, but restyle them as a compact dock-like control strip with consistent icon buttons.
- Slightly widen the panel and increase whitespace so cards, badges, and progress bars have room to breathe.

**Visual System:**
- Use layered system materials with subtle custom fills, thin strokes, and soft shadows.
- Keep colors restrained: cool neutrals for surfaces, teal for healthy state, amber for warning, and red-orange for exhausted or invalid states.
- Use low-saturation accenting for the active account rather than heavy solid fills.
- Replace plain progress bars with capsule tracks and gentle gradients to feel more like an instrument panel.

**Interaction & Motion:**
- Keep the existing refresh rotation and numeric interpolation.
- Add light hover feedback for actionable buttons and account cards.
- Highlight the active account with clearer edge contrast, a soft internal glow, and better button emphasis.
- Avoid dramatic glow sweeps or loud animation so the panel still feels like a serious menu bar utility.

**Implementation Boundaries:**
- Restrict changes to the SwiftUI presentation layer.
- Do not change account switching, OAuth, auto-refresh cadence, notifications, or model semantics.
- Prefer shared SwiftUI style helpers over AppKit-specific customization or new dependencies.

**Testing:**
- Verify the app still builds cleanly with Xcode.
- Manually inspect the menu panel in both light and dark appearance to confirm spacing, legibility, and button affordances.
