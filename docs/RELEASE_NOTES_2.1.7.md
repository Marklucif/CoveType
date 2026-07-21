# CoveType 2.1.7 Public Preview

## Fixes

- Shows the listening panel before microphone initialization so a slow audio device cannot make the shortcut appear unresponsive.
- Fixes the stop-before-start race that could display `No Recording` while an asynchronous WAV recording continued in the background.
- Cancels an older transcription or error state when a new push-to-talk gesture begins.
- Recovers automatically if macOS drops a modifier-key release event, including the custom Command-only shortcut.
- Adds regression coverage for lost modifier release events and keeps the WAV audio pipeline check in the installer and CI.

- Website: `https://covetype.com/`
- Manifest: `https://covetype.com/update.json`
- Release: `https://github.com/Marklucif/CoveType/releases/tag/v2.1.7-beta.1`

SHA-256: `80b6b21e5a18f382ea6084189f8468f1651b6928574d5c33f11afe3b68f3d4de`
