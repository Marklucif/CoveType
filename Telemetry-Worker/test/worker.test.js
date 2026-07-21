import assert from "node:assert/strict";
import test from "node:test";
import { hashInstallID, normalizeCountry, validatePayload } from "../src/index.js";

const validPayload = {
  schema_version: 1,
  installation_id: "3f25a943-88cd-4e9f-8d63-2a5aa713ad53",
  app_version: "2.1.5",
  macos_version: "15.5",
  architecture: "arm64"
};

test("accepts only the documented heartbeat fields", () => {
  assert.deepEqual(validatePayload(validPayload), { ok: true });
  assert.equal(validatePayload({ ...validPayload, schema_version: 2 }).ok, false);
  assert.equal(validatePayload({ ...validPayload, installation_id: "device-1" }).ok, false);
  assert.equal(validatePayload({ ...validPayload, architecture: "iPhone" }).ok, false);
  assert.deepEqual(validatePayload({ ...validPayload, transcript: "must never be accepted" }), {
    ok: false,
    error: "unexpected_field"
  });
});

test("normalizes countries to a two-letter code", () => {
  assert.equal(normalizeCountry("CN"), "CN");
  assert.equal(normalizeCountry("US"), "US");
  assert.equal(normalizeCountry("us"), "XX");
  assert.equal(normalizeCountry(undefined), "XX");
});

test("hashes installation IDs with a server-side secret", async () => {
  const first = await hashInstallID(validPayload.installation_id, "secret-one");
  const second = await hashInstallID(validPayload.installation_id, "secret-one");
  const different = await hashInstallID(validPayload.installation_id, "secret-two");
  assert.equal(first, second);
  assert.notEqual(first, different);
  assert.match(first, /^[0-9a-f]{64}$/);
});
