# CoveType 2.1.8

Apple Developer ID signed and notarized public preview.

## Fixed

- Treat a silent or very short recording as a recoverable “No speech detected” result instead of a Local AI protocol error.
- Keep the already-loaded Qwen3-ASR process alive after an empty recognition result so the next attempt stays responsive.
- Close the overlay immediately after a no-speech result so the user can retry without waiting or dismissing a message.
- Verify the configurable hold threshold with both a short press and a timed long press in the built-in shortcut self-test.

## Verification

- Tested with a real synthesized speech WAV and a zero-speech WAV.
- Passed the release build, shortcut, audio pipeline, update channel, telemetry, and local AI worker tests.
- Gatekeeper assessment: `accepted`, source `Notarized Developer ID`.
- Installer SHA-256: `659c719f6b1f5c11b4f2086e0d063e4c860bacb6cf9d7d7da1745506bfd47a3c`.
