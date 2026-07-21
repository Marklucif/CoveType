# CoveType anonymous usage telemetry

This Cloudflare Worker accepts one best-effort heartbeat per CoveType installation every 24 hours. The client sends readable JSON over HTTPS containing only a random installation UUID, CoveType version, macOS major/minor version, and processor architecture. Cloudflare supplies the two-letter country code at the edge. Audio, transcripts, typed text, application names, email addresses, names, precise location, and raw IP addresses are not written to the database.

The Worker converts the installation UUID to a server-secret HMAC before storage. Raw identifiers are never stored. Daily activity is retained for 90 days; installations inactive for 365 days are deleted by the scheduled cleanup. The protected `/v1/stats` response exposes aggregate counts only.

Endpoints:

- `POST /v1/heartbeat` — public, validated heartbeat receiver.
- `GET /health` — public service health check.
- `GET /v1/stats` — aggregate dashboard JSON requiring `Authorization: Bearer …`.

Required Worker secrets:

- `TELEMETRY_HASH_SECRET` — HMAC secret used before storing installation identifiers.
- `ADMIN_BEARER_TOKEN` — protects aggregate statistics.

Apply `migrations/0001_initial.sql` to the `covetype-telemetry` D1 database before the first production request. Keep Cloudflare observability logs disabled so request metadata is not copied into application logs.
