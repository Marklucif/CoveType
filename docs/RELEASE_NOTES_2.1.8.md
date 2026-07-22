# CoveType 2.1.8 — Installer Revision 2

Apple Developer ID signed and notarized public preview.

## Fixed

- Treat a silent or very short recording as a recoverable “No speech detected” result instead of a Local AI protocol error.
- Keep the already-loaded Qwen3-ASR process alive after an empty recognition result so the next attempt stays responsive.
- Close the overlay immediately after a no-speech result so the user can retry without waiting or dismissing a message.
- Verify the configurable hold threshold with both a short press and a timed long press in the built-in shortcut self-test.
- Preserve macOS quarantine metadata instead of clearing it during installation.
- Require the official Developer ID build to pass stapled-ticket and Gatekeeper checks both before and after copying.
- Roll back an existing app—or remove a failed first install—when the installed trust chain is invalid.
- Document that update backups are temporary and removed after all post-install checks pass.

## Verification

- Tested with a real synthesized speech WAV and a zero-speech WAV.
- Passed the release build, shortcut, audio pipeline, update channel, telemetry, and local AI worker tests.
- Gatekeeper assessment: `accepted`, source `Notarized Developer ID`.
- Release: `https://github.com/Marklucif/CoveType/releases/tag/v2.1.8-beta.2`.
- Installer SHA-256: `5b6248ad30029f43b542a530e10c71fb75b660498110fe3db97fdacd52208afb`.
