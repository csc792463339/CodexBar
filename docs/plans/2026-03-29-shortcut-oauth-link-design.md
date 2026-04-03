# Shortcut OAuth Link Design

**Goal:** Add a fixed global shortcut so Codex Bar can prepare a new OAuth session, start the local callback listener, generate a fresh authorization link, and copy that link to the clipboard without opening the browser.

**Current Context:** The app currently only starts OAuth from [codexBar/Services/OAuthManager.swift](/Users/csc/IdeaProjects/CodexBar/codexBar/Services/OAuthManager.swift), where `startOAuth` always opens the browser after creating a single in-memory session. The menu bar UI already has success and error banners in [codexBar/Views/MenuBarView.swift](/Users/csc/IdeaProjects/CodexBar/codexBar/Views/MenuBarView.swift), and the app entry point is [codexBar/codexBarApp.swift](/Users/csc/IdeaProjects/CodexBar/codexBar/codexBarApp.swift).

**Design:**
- Keep the existing OAuth constants, PKCE generation, and callback handling in `OAuthManager`.
- Split OAuth startup into a reusable session-preparation path that starts the local callback server and returns the generated authorization URL.
- Add a fixed global hotkey, `Command+Shift+L`, registered when the app launches.
- When the hotkey fires, prepare a fresh OAuth session, copy the authorization URL to `NSPasteboard.general`, and publish a success message.
- Do not open the browser automatically.
- Reuse the existing token exchange flow so that when the callback arrives, the account is still added to the app exactly like the current “Add Account” button flow.

**Session Rules:**
- Keep the current single-session model.
- If the user presses the hotkey again before finishing the previous OAuth attempt, replace the pending `state`, `codeVerifier`, completion handler, and local callback listener with the new session.
- This makes the previously copied link invalid by design, which matches the existing singleton `OAuthManager` architecture and keeps the scope small.

**Architecture Notes:**
- Add a lightweight global hotkey service under `codexBar/Services/` using Carbon `RegisterEventHotKey`.
- Expose a published transient message from `OAuthManager` so both the menu bar UI and the hotkey flow can surface success and failure without duplicating banner state machinery in the service layer.
- Keep the “Add Account” button behavior unchanged except that it should now call the shared session-preparation helper and explicitly open the returned URL.

**User Feedback:**
- Success banner text should clearly say that the OAuth link has been copied and mention the shortcut.
- Errors from callback startup, invalid URL generation, or token exchange should still surface through the existing warning banner.

**Testing:**
- Launch the app and press `Command+Shift+L`.
- Confirm the clipboard contains an `https://auth.openai.com/oauth/authorize?...` URL.
- Confirm the local callback listener remains active and the pasted link can still complete the OAuth flow.
- Confirm the existing “Add Account” button still opens the browser and successfully adds an account.
