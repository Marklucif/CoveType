# Contributing to CoveType

Thank you for helping improve CoveType. The project welcomes focused bug fixes, performance work, accessibility improvements, documentation, and well-scoped feature proposals.

## Before opening code changes

1. Search existing issues and open a proposal for behavior changes.
2. Do not include recordings, dictated text, API credentials, signing certificates, model weights, or other private data.
3. Keep the privacy boundary intact: transcription and polishing must remain local unless an explicitly optional network feature is documented and approved.

## Build requirements

- macOS 15 or newer
- Xcode with Swift 6.2 or newer
- Apple silicon for the complete MLX runtime

Build the native client:

```zsh
swift build
```

The full local runtime and models are installed separately:

```zsh
./scripts/install_macos.command
```

## Pull requests

- Keep each pull request focused.
- Explain user-visible behavior and verification steps.
- Update English and Chinese documentation when behavior changes.
- Preserve TypeNo upstream attribution and GPLv3 notices.
- Identify the source and license of every new dependency or asset.

By contributing, you agree that your contribution is distributed under GNU GPLv3.
