const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "x-content-type-options": "nosniff"
};

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const VERSION_PATTERN = /^[0-9A-Za-z][0-9A-Za-z._-]{0,31}$/;
const MACOS_PATTERN = /^\d{1,2}\.\d{1,2}$/;
const ALLOWED_ARCHITECTURES = new Set(["arm64", "x86_64", "unknown"]);
const ALLOWED_PAYLOAD_FIELDS = new Set([
  "schema_version",
  "installation_id",
  "app_version",
  "macos_version",
  "architecture"
]);

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/health") {
      return jsonResponse({ ok: true, service: "covetype-telemetry", schema_version: 1 });
    }

    if (request.method === "POST" && url.pathname === "/v1/heartbeat") {
      return handleHeartbeat(request, env);
    }

    if (request.method === "GET" && url.pathname === "/v1/stats") {
      return handleStats(request, env);
    }

    return jsonResponse({ ok: false, error: "not_found" }, 404);
  },

  async scheduled(_controller, env) {
    const now = new Date();
    const activityCutoff = isoDay(addDays(now, -90));
    const installationCutoff = addDays(now, -365).toISOString();
    await env.DB.batch([
      env.DB.prepare("DELETE FROM daily_activity WHERE day < ?").bind(activityCutoff),
      env.DB.prepare("DELETE FROM installations WHERE last_seen < ?").bind(installationCutoff)
    ]);
  }
};

async function handleHeartbeat(request, env) {
  if (!env.DB || !env.TELEMETRY_HASH_SECRET) {
    return jsonResponse({ ok: false, error: "service_not_configured" }, 503);
  }

  const contentType = request.headers.get("content-type")?.toLowerCase() || "";
  if (!contentType.startsWith("application/json")) {
    return jsonResponse({ ok: false, error: "content_type_must_be_json" }, 415);
  }

  const declaredLength = Number(request.headers.get("content-length") || "0");
  if (Number.isFinite(declaredLength) && declaredLength > 4096) {
    return jsonResponse({ ok: false, error: "payload_too_large" }, 413);
  }

  let payloadText;
  try {
    payloadText = await request.text();
  } catch {
    return jsonResponse({ ok: false, error: "invalid_json" }, 400);
  }
  if (new TextEncoder().encode(payloadText).byteLength > 4096) {
    return jsonResponse({ ok: false, error: "payload_too_large" }, 413);
  }

  let payload;
  try {
    payload = JSON.parse(payloadText);
  } catch {
    return jsonResponse({ ok: false, error: "invalid_json" }, 400);
  }

  const validation = validatePayload(payload);
  if (!validation.ok) {
    return jsonResponse({ ok: false, error: validation.error }, 400);
  }

  if (!(await applyHeartbeatRateLimits(request, payload.installation_id, env))) {
    return jsonResponse({ ok: false, error: "rate_limited" }, 429);
  }

  const now = new Date();
  const timestamp = now.toISOString();
  const day = isoDay(now);
  const country = normalizeCountry(request.cf?.country);
  const installHash = await hashInstallID(payload.installation_id, env.TELEMETRY_HASH_SECRET);

  await env.DB.batch([
    env.DB.prepare(`
      INSERT INTO installations (
        install_hash, first_seen, last_seen, country, app_version, macos_version, architecture
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(install_hash) DO UPDATE SET
        last_seen = excluded.last_seen,
        country = excluded.country,
        app_version = excluded.app_version,
        macos_version = excluded.macos_version,
        architecture = excluded.architecture
    `).bind(
      installHash,
      timestamp,
      timestamp,
      country,
      payload.app_version,
      payload.macos_version,
      payload.architecture
    ),
    env.DB.prepare(`
      INSERT INTO daily_activity (
        day, install_hash, country, app_version, macos_version, architecture
      ) VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(day, install_hash) DO UPDATE SET
        country = excluded.country,
        app_version = excluded.app_version,
        macos_version = excluded.macos_version,
        architecture = excluded.architecture
    `).bind(
      day,
      installHash,
      country,
      payload.app_version,
      payload.macos_version,
      payload.architecture
    )
  ]);

  return jsonResponse({ ok: true, accepted: true }, 202);
}

async function handleStats(request, env) {
  if (!env.DB || !env.ADMIN_BEARER_TOKEN) {
    return jsonResponse({ ok: false, error: "service_not_configured" }, 503);
  }

  const authorization = request.headers.get("authorization") || "";
  if (authorization !== `Bearer ${env.ADMIN_BEARER_TOKEN}`) {
    return jsonResponse({ ok: false, error: "unauthorized" }, 401);
  }

  const now = new Date();
  const today = isoDay(now);
  const sevenDaysAgo = isoDay(addDays(now, -6));
  const thirtyDaysAgo = isoDay(addDays(now, -29));

  const [totals, countries, versions, systems] = await Promise.all([
    env.DB.prepare(`
      SELECT
        (SELECT COUNT(*) FROM installations) AS known_installations,
        (SELECT COUNT(DISTINCT install_hash) FROM daily_activity WHERE day = ?) AS active_today,
        (SELECT COUNT(DISTINCT install_hash) FROM daily_activity WHERE day >= ?) AS active_7_days,
        (SELECT COUNT(DISTINCT install_hash) FROM daily_activity WHERE day >= ?) AS active_30_days
    `).bind(today, sevenDaysAgo, thirtyDaysAgo).first(),
    env.DB.prepare(`
      SELECT country, COUNT(DISTINCT install_hash) AS active_devices
      FROM daily_activity
      WHERE day >= ?
      GROUP BY country
      ORDER BY active_devices DESC, country ASC
    `).bind(thirtyDaysAgo).all(),
    env.DB.prepare(`
      SELECT app_version, COUNT(DISTINCT install_hash) AS active_devices
      FROM daily_activity
      WHERE day >= ?
      GROUP BY app_version
      ORDER BY active_devices DESC, app_version DESC
    `).bind(thirtyDaysAgo).all(),
    env.DB.prepare(`
      SELECT macos_version, architecture, COUNT(DISTINCT install_hash) AS active_devices
      FROM daily_activity
      WHERE day >= ?
      GROUP BY macos_version, architecture
      ORDER BY active_devices DESC, macos_version DESC
    `).bind(thirtyDaysAgo).all()
  ]);

  return jsonResponse({
    ok: true,
    generated_at: now.toISOString(),
    totals: totals || {
      known_installations: 0,
      active_today: 0,
      active_7_days: 0,
      active_30_days: 0
    },
    countries_30_days: countries.results || [],
    versions_30_days: versions.results || [],
    systems_30_days: systems.results || []
  });
}

export function validatePayload(payload) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return { ok: false, error: "payload_must_be_an_object" };
  }
  if (Object.keys(payload).some((field) => !ALLOWED_PAYLOAD_FIELDS.has(field))) {
    return { ok: false, error: "unexpected_field" };
  }
  if (payload.schema_version !== 1) {
    return { ok: false, error: "unsupported_schema" };
  }
  if (typeof payload.installation_id !== "string" || !UUID_PATTERN.test(payload.installation_id)) {
    return { ok: false, error: "invalid_installation_id" };
  }
  if (typeof payload.app_version !== "string" || !VERSION_PATTERN.test(payload.app_version)) {
    return { ok: false, error: "invalid_app_version" };
  }
  if (typeof payload.macos_version !== "string" || !MACOS_PATTERN.test(payload.macos_version)) {
    return { ok: false, error: "invalid_macos_version" };
  }
  if (!ALLOWED_ARCHITECTURES.has(payload.architecture)) {
    return { ok: false, error: "invalid_architecture" };
  }
  return { ok: true };
}

export function normalizeCountry(country) {
  return typeof country === "string" && /^[A-Z]{2}$/.test(country) ? country : "XX";
}

export async function hashInstallID(installationID, secret) {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(installationID));
  return [...new Uint8Array(signature)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function applyHeartbeatRateLimits(request, installationID, env) {
  if (env.HEARTBEAT_INSTALL_LIMITER) {
    const result = await env.HEARTBEAT_INSTALL_LIMITER.limit({ key: installationID });
    if (!result.success) return false;
  }

  if (env.HEARTBEAT_SOURCE_LIMITER) {
    // This value is used only as an ephemeral Cloudflare rate-limit key. It is
    // never written to D1 or included in application statistics.
    const source = request.headers.get("cf-connecting-ip") || "unknown-source";
    const result = await env.HEARTBEAT_SOURCE_LIMITER.limit({ key: source });
    if (!result.success) return false;
  }
  return true;
}

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

function isoDay(date) {
  return date.toISOString().slice(0, 10);
}

function addDays(date, days) {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}
