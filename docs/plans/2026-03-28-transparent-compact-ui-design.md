# Transparent Compact UI Design

**Goal:** Refine the current menu bar and dropdown UI so it fits comfortably, uses a clearer fully transparent glass direction, and avoids oversized controls.

**Current Context:** The recent glassmorphism pass improved visual richness but introduced proportion problems. The menu bar label is too wide, the dropdown panel is too narrow for the amount of content, and the glass layers are too milky, which reduces clarity and makes the UI feel heavy.

**Approved Direction:** Shift from soft milky translucency to a cleaner crystal-glass look. Widen the dropdown to 440px, shrink controls globally, stack the menu bar metrics vertically, and remove the oversized leading menubar icon in favor of a minimal status marker.

**Design:**
- Replace the menu bar icon+single-line text layout with a compact status dot and two stacked metric lines.
- Expand the dropdown width to 440px so account rows and summary content are not forced into aggressive truncation.
- Shrink badges, buttons, paddings, corner radii, and row heights across the panel.
- Remove the foggy semi-opaque fills and switch to more transparent surfaces with clearer edges and better text contrast.

**Visual System:**
- Use transparent fills with low-opacity strokes, bright top-edge highlights, and restrained shadows instead of thick milky materials.
- Keep text darker and more contrast-stable so the UI remains legible over varied wallpapers.
- Keep state colors, but reduce their surface coverage so they guide attention without overpowering the layout.

**Interaction & Motion:**
- Preserve existing refresh and numeric transitions.
- Keep hover feedback, but make it subtler and less puffy.
- Avoid any oversized circular control treatment that steals focus from the account data.

**Implementation Boundaries:**
- Restrict changes to SwiftUI view code and styling helpers.
- Do not change model, OAuth, refresh cadence, or account switching logic.

**Testing:**
- Build with unsigned Debug configuration.
- Manually inspect whether the menu bar item becomes narrower and the dropdown shows content without clipping.
