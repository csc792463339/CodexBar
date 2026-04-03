# OAuth Link CLI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a standalone Python CLI that generates and lists persisted Codex Bar-compatible OAuth authorization link sessions.

**Architecture:** Add a new root-level Python script with `argparse` subcommands. Keep OAuth constants aligned with the Swift app, generate PKCE values locally, persist each session to a JSON file under `~/.codex/oauth-sessions/`, and expose `create` plus `list` commands with both human-readable and JSON output modes.

**Tech Stack:** Python 3, argparse, json, pathlib, hashlib, base64, urllib.parse

---

### Task 1: Add the standalone CLI script

**Files:**
- Create: `oauth_link_cli.py`

**Step 1: Add OAuth constants and PKCE helpers**

Define the authorize URL, client ID, redirect URI, scope, originator, and helper functions for URL-safe base64 plus SHA-256 PKCE challenge generation.

**Step 2: Add session storage helpers**

Resolve the real home directory, create the default session directory, and add functions to read and write individual session JSON files.

**Step 3: Add the `create` subcommand**

Generate one or more sessions, save them, and print either text or JSON output that includes the authorization URL.

**Step 4: Add the `list` subcommand**

Load saved sessions from disk, sort them newest-first, and print either text or JSON output.

### Task 2: Document the CLI design

**Files:**
- Create: `docs/plans/2026-03-29-oauth-link-cli-design.md`
- Create: `docs/plans/2026-03-29-oauth-link-cli.md`

**Step 1: Record the approved scope**

Document that this CLI only generates and lists authorization links and intentionally does not perform callback handling or token exchange.

**Step 2: Record storage and compatibility details**

Document the persisted session format and the requirement to stay aligned with `OAuthManager.swift`.

### Task 3: Verify the script

**Files:**
- Modify: none

**Step 1: Create temporary sessions**

Run: `python3 oauth_link_cli.py create --count 2 --session-dir /tmp/codexbar-oauth-test`

Expected: exit code `0`, two sessions written, and two authorization URLs printed.

**Step 2: List temporary sessions**

Run: `python3 oauth_link_cli.py list --session-dir /tmp/codexbar-oauth-test`

Expected: exit code `0`, both stored sessions listed in newest-first order.

**Step 3: Verify JSON mode**

Run: `python3 oauth_link_cli.py create --count 1 --json --session-dir /tmp/codexbar-oauth-test-json`

Expected: exit code `0` and valid JSON output containing the generated authorization URL and persisted session metadata.
