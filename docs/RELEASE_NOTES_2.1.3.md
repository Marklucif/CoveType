# CoveType 2.1.3 Public Preview

CoveType is a privacy-first local AI voice-input app for Apple silicon Macs. Hold your chosen shortcut to speak, release it to transcribe, and CoveType inserts the result into the active app.

## Highlights

- Local Qwen3-ASR 0.6B 8-bit speech recognition with automatic detection across 30 languages.
- Optional local Qwen3.5 0.8B 4-bit text polishing.
- Apple on-device translation with 15 selectable output languages.
- User-recordable hold-to-talk shortcuts and adjustable hold duration, designed not to interfere with shortcuts such as Control-C.
- Live listening waveform and a gradient breathing menu-bar lamp.
- Native feedback window that lets the user review or copy feedback before opening a GitHub issue.
- On-demand AI worker reuse with automatic idle memory release.
- Guided installer with system-language permission instructions, permission checks, model setup, and launch at login.

## Requirements

- Apple silicon Mac (M1 or newer)
- macOS 15 or later
- 8 GB memory minimum; 16 GB recommended
- At least 5 GB free storage
- Internet access during the first installation

## Install

1. Download and extract `CoveType-2.1.3-macOS-AppleSilicon-Installer.zip`.
2. Control-click `Install CoveType.command` and choose **Open**.
3. Follow the guided installer and approve Microphone and Accessibility access when macOS asks.

This public-preview build is signed with an Apple Developer ID but is not yet notarized. On first launch, macOS may require Control-clicking CoveType and choosing **Open**.

SHA-256: `6ea8315f9451e9661f8ad152d3f97d42087f5937a811cc9b9757419f0233d716`
