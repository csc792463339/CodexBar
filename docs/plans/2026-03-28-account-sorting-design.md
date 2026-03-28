# Account Sorting Design

**Goal:** Update the account list ordering so the currently active account is always first and all remaining accounts are ordered by remaining quota.

**Current Context:** The menu groups accounts by email and currently sorts groups and rows by active status plus usage status. The view logic lives in `codexBar/Views/MenuBarView.swift`.

**Design:**
- Keep the existing email-grouped UI so the visible structure does not change.
- Define a single account comparator for both group ordering and row ordering.
- Rank the active account first regardless of quota.
- Rank non-active accounts by remaining 5-hour quota descending, then remaining weekly quota descending.
- Use stable string tie-breakers to avoid list jitter when quotas are equal.

**Quota Semantics:**
- Remaining 5-hour quota = `100 - primaryUsedPercent`
- Remaining weekly quota = `100 - secondaryUsedPercent`

**Error Handling:** Missing usage values already decode to `0`, so remaining quota naturally falls back to `100` for untouched accounts and `0` for exhausted accounts through the existing model defaults.

**Testing:** Verify by building the app and checking that the changed comparator compiles cleanly.
