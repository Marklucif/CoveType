# CoveType 2.1.5 Public Preview

## Changes

- Adds a transparent anonymous usage heartbeat, enabled by default and switchable in the **Send Feedback…** window.
- Limits telemetry to one HTTPS attempt every 24 hours.
- Sends only a random installation ID, CoveType version, macOS version, and processor architecture.
- Derives country at the Cloudflare edge without storing raw IP addresses.
- Stores only a server-secret HMAC of the installation ID and exposes aggregate statistics through a protected endpoint.
- Publishes localized website disclosure and a complete privacy document.

Audio, transcripts, typed text, clipboard data, application names, and precise location are never included.

- Website: `https://covetype.com/`
- Manifest: `https://covetype.com/update.json`
- Release: `https://github.com/Marklucif/CoveType/releases/tag/v2.1.5-beta.1`

SHA-256: `02ce7cf09ff1e79fba6218098b265cf9ce1a5599bf67073511bd9166ed59e592`
