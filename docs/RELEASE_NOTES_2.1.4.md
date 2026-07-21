# CoveType 2.1.4 Public Preview

This maintenance release verifies the complete CoveType update path now that the public update channel is live.

## Fixed

- Fixed the installer update-channel self-test, which still expected the public channel to be unavailable and could incorrectly fail at the end of an otherwise successful installation.
- The self-test now accepts both valid states: already up to date or a newer CoveType release available.
- Added explicit diagnostic output for the resolved version and CoveType release URL.

## Update path

- Manifest: `https://marklucif.github.io/CoveType/update.json`
- Release: `https://github.com/Marklucif/CoveType/releases/tag/v2.1.4-beta.1`
- Bundle identifier: `ai.covetype.app`
- Channel: `covetype-local-ai-stable`

## Requirements

- Apple silicon Mac (M1 or newer)
- macOS 15 or later
- 8 GB memory minimum; 16 GB recommended
- At least 5 GB free storage
- Internet access during the first installation

This public-preview build is signed with an Apple Developer ID but is not yet notarized. On first launch, macOS may require Control-clicking CoveType and choosing **Open**.

SHA-256: `5c345c32a38f871d46ea0e320d503bb66c5d5a1d114d7431c1b78583dc272e2b`
