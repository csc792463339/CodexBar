# Quota Window Detection Design

**Goal:** Fix quota parsing so Free accounts display the correct 7-day window, and show the next refresh time in the UI without regressing existing multi-window accounts.

**Current Context:** The quota fetch path lives in `codexBar/Services/WhamService.swift`, persisted values live in `codexBar/Models/TokenAccount.swift`, and the visible quota UI is split across `codexBar/Views/AccountRowView.swift`, `codexBar/Views/MenuBarView.swift`, and `codexBar/codexBarApp.swift`.

**Observed API Behavior:** A live `free` response from `https://chatgpt.com/backend-api/wham/usage` returns `rate_limit.primary_window.limit_window_seconds = 604800` and `rate_limit.secondary_window = null`. This proves the API window names no longer map reliably to `5H` and `7D`.

**Design:**
- Stop assigning meaning based on the response key name `primary_window` or `secondary_window`.
- Classify each returned window by `limit_window_seconds`.
- Map `18000` seconds to the app's 5-hour slot and `604800` seconds to the app's 7-day slot.
- Leave missing windows empty instead of fabricating placeholder values.
- Keep the persisted model shape compatible by continuing to store the app-level `5H` slot in `primary*` fields and the app-level `7D` slot in `secondary*` fields.

**UI Changes:**
- Only render quota cards for windows that actually exist.
- For `free` accounts, this means showing only the `7D` card.
- Show an absolute “next refresh” timestamp for each visible quota window.
- Keep the existing relative reset countdown as secondary context where it still helps.
- Update the active-account summary and the menu bar icon so they reflect real visible windows instead of always rotating fixed `5H` / `7D` labels.

**Behavioral Changes Outside the Card UI:**
- Sorting and auto-switch decisions should consider the best available real quota window instead of assuming `primaryUsedPercent` always represents the 5-hour window.
- Warning and exhausted states should continue to work for accounts that only expose one quota window.

**Error Handling:**
- Unknown window durations should be ignored instead of misclassified.
- Missing `reset_at` values should hide the “next refresh” timestamp for that window.
- Existing stale data should be overwritten on the next successful refresh with the corrected mapping.

**Testing:**
- Build the app after the parsing and UI updates.
- Verify a real `free` response maps into the `7D` slot only.
- Verify a synthetic dual-window response still renders both `5H` and `7D`.
