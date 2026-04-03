# Account Sort Design

**Goal:** Update the menu account list so display ordering follows remaining quota first, then quota window dimension, then email name.

**Current Context:** Account list grouping and sorting live in `codexBar/Views/MenuBarView.swift`. Quota window data and account-level computed helpers live in `codexBar/Models/TokenAccount.swift`.

## Approved Rules

1. Sort by remaining quota, higher remaining quota first.
2. Within quota sorting, compare the `5H` window before the `7D` window.
3. If an account does not have the compared quota window, it should sort after one that does.
4. If quota values are tied, sort by email name ascending.
5. Keep the existing email-grouped UI structure; only change display ordering.
6. Do not change `autoSwitchIfNeeded()` in this task.

## Design

- Add a dedicated display sort key in `TokenAccount` so the list ordering rule is defined in one place instead of inside the view.
- The sort key will expose:
  - `5H` remaining percent with missing-window handling
  - `7D` remaining percent with missing-window handling
  - normalized email for alphabetical fallback
  - `accountId` for deterministic final tie-breaking
- Update `MenuBarView` to use the model-backed sort key for:
  - ordering accounts inside each email group
  - choosing the best account that determines each email group's position

## Verification

- Build the app successfully after the change.
- Confirm the list no longer prioritizes the active account over quota ordering.
- Confirm accounts with higher `5H` remaining quota sort ahead of lower ones.
- Confirm ties on `5H` fall back to `7D`.
- Confirm ties on quota values fall back to email name.
