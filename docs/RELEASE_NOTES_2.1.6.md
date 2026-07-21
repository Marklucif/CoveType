# CoveType 2.1.6 Public Preview

## Fixes

- Records microphone input as WAV so local Qwen3-ASR no longer depends on an external FFmpeg executable.
- Fixes the FFmpeg-not-found error that could appear after launching CoveType from Finder or at login, where Homebrew paths are not inherited.
- Removes abandoned temporary recordings at startup and immediately after a failed transcription.
- Makes the end-to-end test follow the production fallback policy: a rejected optional polish result no longer marks successful speech recognition as failed.

- Website: `https://covetype.com/`
- Manifest: `https://covetype.com/update.json`
- Release: `https://github.com/Marklucif/CoveType/releases/tag/v2.1.6-beta.1`

SHA-256: `cd7e1c336d7aadc10fc101344164aa2111a6c88af13559a4447553d659542cfb`
