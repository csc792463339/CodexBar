# App Icon Refresh Design

**Goal:** Refresh the macOS app icon so it reflects the product's Codex-plus-usage-monitoring identity while staying legible at very small Finder and Dock sizes.

**Current Context:** The app is a macOS menu bar utility for switching ChatGPT/Codex accounts and tracking quota usage. The current raster icon set lives in `codexBar/Assets.xcassets/AppIcon.appiconset`, and the repository also includes a separate brand mark source in `codexBar/Assets/logo.svg`.

**Approved Direction:** Use the provided reference image as inspiration, but simplify it into a macOS-friendly icon. Preserve the recognizable concept of a cloud, terminal prompt, usage bars, and upward trend arrow, while removing decorative sparkles, overly soft glow, and other details that collapse at `16x16` and `32x32`.

**Design:**
- Keep a rounded light tile background to match modern macOS app icon presentation.
- Use a single bold cloud silhouette as the main shape, filled with a blue-to-violet gradient.
- Center a white terminal prompt (`>_`) inside the cloud to anchor the Codex identity.
- Place a compact rising usage chart on the right side of the cloud and integrate an upward arrow into the top-right edge.
- Use restrained glow and highlight treatment so the icon still feels polished without turning blurry at small sizes.

**Visual System:**
- Background: soft neutral tile with subtle edge shading.
- Primary shape: saturated blue / violet gradient with stronger outline separation than the reference.
- Foreground symbols: high-contrast white prompt and bright cyan chart elements.
- Effects: only mild highlight and shadow layers; no star particles or tiny circuitry details.

**Implementation Boundaries:**
- Update only icon and logo assets.
- Keep `AppIcon.appiconset/Contents.json` unchanged.
- Do not change the menu bar runtime icon system or application behavior.

**Testing:**
- Confirm the generated PNG set matches required asset sizes.
- Inspect the rendered `16x16`, `32x32`, `128x128`, and `1024x1024` outputs for clarity.
- Build the app to ensure the asset catalog still compiles cleanly.
