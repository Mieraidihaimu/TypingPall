# Releasing TypingPall

The 1.1.0 source is prepared for direct Mac distribution. Shipping requires a Developer ID Application certificate and notarization. Nothing in the build scripts uploads or publishes an app.

## Validate

Run `./scripts/check.sh` on a Mac with full Xcode selected. This runs unit and UI tests, then builds Release for Apple silicon and Intel. UI tests need a logged-in desktop with permission for the Xcode test runner to control it. To run unit tests independently, pass `-only-testing:TypingPallTests`.

Before distribution, smoke-test the signed app on macOS 12 and a current macOS release, on both architectures where available. Exercise importing a UTF-8 file, line-by-line progression, repeating a line, blank lines, tab expansion, emoji, IME composition, undo/redo, window resizing, light/dark appearance, VoiceOver, persistence after relaunch, and upgrading an installation with saved scripts. The deployment target alone is not proof of runtime compatibility.

## Sign and archive

Set `DEVELOPMENT_TEAM` and `SIGNING_IDENTITY` to your team and installed Developer ID Application certificate, then run `./scripts/archive.sh`. It builds a universal archive with hardened runtime and verifies its code signature. It refuses to overwrite an existing archive.

Open the archive in Xcode Organizer and choose the Developer ID distribution workflow. Complete notarization, export the app, and verify the exported artifact before making it available to users. Apple documents [notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) and [custom notarization workflows](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

Keep credentials in Keychain or CI secrets. Commit neither certificates nor credentials. Increment the marketing version and build number for subsequent releases. Include the GPL license and corresponding source when distributing binaries.

## Existing data and sandboxing

This release retains the existing `com.mier.TypingPall` bundle ID, `TypingPall` Core Data model and default store location. Lightweight migration remains enabled. Failed loads show a retry screen and never delete or replace the store. Failed writes roll back and show an error.

The historical sandbox entitlements file is intentionally not attached to the direct-distribution target. Enabling sandboxing changes the home directory and can hide existing users' libraries. A Mac App Store release requires a separate, tested sandbox migration, signing configuration and store submission. The app makes no network requests and collects no analytics.

## Current scope

Practice is organized around code patterns. Leading spaces and tabs are excluded from each typing target while indentation remains visible in the reference. The remaining content must match before Return or Next Line advances. A matching final line completes the pattern only when confirmed. Repeat Line clears only the current attempt; Repeat Pattern starts again at the first line. Internal blank lines are practiced explicitly. A terminal newline does not add an extra exercise. Multiline pastes into the practice input are rejected; pattern imports and the Add Script sheet accept complete snippets.

The full pattern stays visible with the current line highlighted. Progress counts confirmed lines; timing and speed metrics are absent from the practice flow. Session progress is not persisted across launches. Source patterns remain in the library.

Reference and input use separate native views; the active wrapper retains its historical `TextKit2TypingEditor` name but makes no TextKit 2 performance claim. Earlier editor and statistics experiments remain on disk, excluded from the app's Sources phase. The [archived modernization documents](docs/archive/README.md) are historical proposals, not release guarantees.
