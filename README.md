# CoveType

[中文](README_CN.md) | [Windows plan](docs/WINDOWS.md)

[Website](https://marklucif.github.io/CoveType/) · [Download](https://github.com/Marklucif/CoveType/releases/tag/v2.1.4-beta.1) · [Feedback](https://github.com/Marklucif/CoveType/issues/new) · [Upstream](https://github.com/marswaveai/TypeNo)

**CoveType** is a privacy-first, local-AI voice-input app for macOS, derived from the open-source TypeNo project. Hold a shortcut to speak, release it to transcribe locally with Qwen3-ASR, optionally polish or translate on device, and paste the result back into the previous app.

![CoveType — Private AI voice typing for Mac](assets/covetype-github-hero.png)

## Features

- Local Qwen3-ASR 0.6B 8-bit recognition with automatic language detection.
- Local Qwen3.5 0.8B 4-bit text polishing.
- Apple on-device instant translation with 15 target-language choices.
- Live microphone waveform and selectable input device.
- A low-overhead breathing menu-bar lamp with distinct colors for idle, listening, local processing, completion, permission, update, and error states.
- A native in-app feedback window for categorized change requests, optional system details, and privacy-aware review before submission.
- On-demand AI worker with short-term reuse and idle memory release.
- No account. Recognition, polishing, and previously downloaded translation packs work offline.
- An isolated CoveType update channel; upstream TypeNo releases can never overwrite this local-AI build.

## Shortcuts

| Action | Trigger |
|---|---|
| Push to talk | Hold the recorded key or key combination, release to stop |
| Automatic compatibility mode | Hold `Fn`, either `Option/Alt`, or either `Control` |
| Hands-free toggle | `Fn + Space` to start/stop |
| Cancel | `Esc` |

Open menu-bar CoveType → **Shortcut Settings…** to record the physical key/key combination and choose a hold delay from 0.10 to 1.50 seconds. The default is 0.32 seconds. A modifier used in another chord before that delay expires is treated as a normal shortcut, so development shortcuts such as `Control + C` remain untouched. **Reset to Automatic** restores Fn/Option/Control compatibility mode.

## Automated macOS installation

Use `dist/CoveType-2.1.4-macOS-AppleSilicon-Installer.zip`, extract it, then open `Install CoveType.command`. The installer sets up the app, isolated Python/MLX runtime, both models, launch at login, defaults, and post-install self-tests. Its permission guide follows the macOS default language, opens the correct System Settings pages, and verifies the result. Updates replace the bundle contents in place. Custom shortcut settings are preserved across upgrades.

CoveType does not query or install releases from `marswaveai/TypeNo`. It uses its own manifest and releases under `Marklucif/CoveType`. See [custom update channel](docs/UPDATE_CHANNEL.md).

The menu-bar **Send Feedback…** window prepares a new issue in `Marklucif/CoveType` for the user to review before publishing. It never sends feedback silently, and **Copy Feedback** remains available without a network request.

The first binary is published as a public preview because Apple notarization credentials are not configured in this development environment. The app is Developer ID signed, but a downloaded build may still require **Control-click → Open** on first launch. Source builds are unaffected.

Requirements: Apple Silicon, macOS 15 or later, an internet connection for first install, and 5 GB free disk space. See [the full macOS installation guide](docs/MACOS_AUTOMATED_INSTALL.md).

From the source tree:

```zsh
./scripts/install_macos.command
```

macOS privacy controls still require the signed-in user to approve Microphone, Accessibility, and each Apple translation language pack on first use.

## Windows

The macOS client cannot be copied directly to Windows because it uses AppKit/SwiftUI, AVFoundation, Apple Translation, and MLX. This repository includes an automated official Qwen3-ASR/PyTorch backend bootstrap and browser demo for Windows; a complete global-input tray client requires a separate native .NET port. See [the Windows plan](docs/WINDOWS.md).

## License and upstream

Based on [marswaveai/TypeNo](https://github.com/marswaveai/TypeNo), licensed under GNU General Public License v3.0. CoveType modifications are maintained at [Marklucif/CoveType](https://github.com/Marklucif/CoveType). Models and dependencies retain their respective licenses.
