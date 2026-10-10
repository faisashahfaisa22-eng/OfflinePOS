import postgres from "npm:postgres@3.4.5";

const respond = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status, headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
const enc = new TextEncoder();
const base64url = (data: Uint8Array) =>
  btoa(String.fromCharCode(...data)).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
const digest = async (s: string) => {
  const bytes = new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(s)));
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
};

Deno.serve(async (request) => {
  if (request.method !== "POST") return respond({ error: "method_not_allowed" }, 405);
  const dbUrl = Deno.env.get("DATABASE_URL");
  const signingKey = Deno.env.get("QAMVIO_LICENSE_ED25519_PKCS8");
  if (!dbUrl || !signingKey) return respond({ error: "server_not_configured" }, 503);
  let input: { code?: unknown; device_id?: unknown };
  try { input = await request.json(); }
  catch { return respond({ error: "invalid_json" }, 400); }
  const code = typeof input.code === "string" ? input.code.trim() : "";
  const deviceId = typeof input.device_id === "string" ? input.device_id : "";
  if (code.length < 20 || code.length > 200 ||
      !/^[A-Za-z0-9_-]{32,100}$/.test(deviceId)) {
    return respond({ error: "invalid_input" }, 400);
  }
  const sql = postgres(dbUrl, { max: 1, connect_timeout: 8, idle_timeout: 3 });
  try {
    const codeHash = await digest(code);
    const deviceHash = await digest(deviceId);
    const rows = await sql`select * from licensing_private.claim_device(${codeHash}, ${deviceHash})`;
    if (!rows.length || rows[0].outcome !== "accepted") {
      return respond({ error: "activation_rejected" }, 403);
    }
    const now = Math.floor(Date.now() / 1000);
    const licensedUntil = rows[0].expires_at
      ? Math.floor(new Date(rows[0].expires_at).getTime() / 1000)
      : now + 30 * 86400;
    const exp = Math.min(now + 30 * 86400, licensedUntil);
    if (exp <= now) return respond({ error: "expired" }, 403);
    const payload = base64url(enc.encode(JSON.stringify({
      typ: "qamvio-license-v1", license_id: rows[0].license_id,
      device_id: deviceId, iat: now, exp,
    })));
    const keyBytes = Uint8Array.from(atob(signingKey), (c) => c.charCodeAt(0));
    const key = await crypto.subtle.importKey("pkcs8", keyBytes,
      { name: "Ed25519" }, false, ["sign"]);
    const signature = new Uint8Array(
      await crypto.subtle.sign("Ed25519", key, enc.encode(payload)));
    return respond({ token: payload + "." + base64url(signature), exp });
  } catch (_) {
    return respond({ error: "activation_unavailable" }, 503);
  } finally {
    await sql.end({ timeout: 2 });
  }
});
