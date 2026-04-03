# OAuth Link CLI Design

**Goal:** Add a standalone Python CLI that generates Codex Bar-compatible OAuth authorization links and persists the session metadata needed to manage and later complete those OAuth sessions outside the GUI.

**Current Context:** The app currently generates OAuth links only inside [codexBar/Services/OAuthManager.swift](/Users/csc/IdeaProjects/codexbar/codexBar/Services/OAuthManager.swift), where `state` and `codeVerifier` live only in memory. The repository also contains a standalone Python script, [openai_reg.py](/Users/csc/IdeaProjects/codexbar/openai_reg.py), which already uses `argparse` and includes small OAuth helper functions.

**Design:**
- Create a new root-level script, `oauth_link_cli.py`, instead of modifying the existing app target or the existing registration script.
- Keep the OAuth parameters aligned with `OAuthManager.swift`, including the client ID, redirect URI, scope, `originator`, and PKCE `S256` challenge generation.
- Persist each generated session as a separate JSON file under `~/.codex/oauth-sessions/` by default so sessions survive app restarts and can be listed later.
- Store enough data for future tools to finish the flow: `session_id`, `created_at`, `state`, `code_verifier`, `code_challenge`, `authorize_url`, and the request parameters used to build it.

**CLI Surface:**
- `create`: Generate one or more OAuth sessions and print the resulting authorization URLs.
- `list`: Read the stored session files and list previously generated authorization URLs.
- Support `--json` for machine-readable output.
- Support `--session-dir` so verification can use a temporary directory instead of the real `~/.codex` path.

**Storage Format:**
- One JSON file per session.
- File name: `<session_id>.json`
- Session directory: `~/.codex/oauth-sessions/`
- JSON shape keeps fields explicit instead of nesting them deeply, so it is easy to inspect and extend later.

**Error Handling:**
- Refuse invalid counts such as `0` or negative values.
- Create the session directory automatically when needed.
- Ignore malformed session files during `list` but report how many were skipped.
- Exit non-zero on argument validation or write failures.

**Testing:**
- Run `python3 oauth_link_cli.py create --count 2 --session-dir /tmp/...` and confirm that two JSON session files and two authorization URLs are produced.
- Run `python3 oauth_link_cli.py list --session-dir /tmp/...` and confirm the stored sessions are listed in newest-first order.
- Run the same commands with `--json` to confirm the script remains automation-friendly.
