# Smoky Glass Refinement Design

**Goal:** Rework the menu panel into a slimmer, more refined 2026-style utility UI using a cold gray smoky-glass direction instead of the current puffy, milky glass treatment.

**Current Context:** The latest panel widened the layout and reduced truncation, but the visual language is still too soft, wide, and bulky. The top summary area dominates too much, account cards feel padded and heavy, and email grouping is not visually strong enough to anchor the list.

**Approved Direction:** Use a cold gray smoky-glass aesthetic with thin edges, restrained highlights, darker text contrast, slimmer controls, and clearer vertical rhythm. Keep the 440px width, but make the panel feel visually lean by compressing block height and removing oversized circular and pill shapes.

**Design:**
- Compress the top summary card into a single slim overview strip that only shows the app name, the active account summary, and a refresh control.
- Promote each email group into a clear section title with strong hierarchy, instead of treating it like a secondary caption.
- Reshape account cards into longer, slimmer strips with reduced vertical padding and smaller status elements.
- Flatten the bottom tool strip into a low-profile control bar.

**Visual System:**
- Replace the bright milky glass look with cool neutral gray surfaces, faint smoke-blue highlights, thin white edge reflections, and deeper graphite text.
- Reduce border radii and surface opacity so each layer feels sharper and more modern.
- Use color only as controlled accents for status and active state, not as large tinted surfaces.

**Interaction & Motion:**
- Preserve current transitions and hover states, but keep them understated.
- Avoid oversized floating button treatment and keep motion subordinate to structure.

**Implementation Boundaries:**
- Restrict changes to SwiftUI presentation files and shared styling helpers.
- Do not touch models, OAuth, account switching, notifications, or refresh logic.

**Testing:**
- Build the app with unsigned Debug configuration.
- Confirm the panel feels slimmer, the email titles stand out clearly, and the top strip no longer overpowers the list.
