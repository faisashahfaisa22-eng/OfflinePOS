// Admin endpoint requires a valid Supabase Auth JWT and a server-side
// administrator allowlist. It does not accept authorization from request JSON.
// Configure QAMVIO_LICENSE_ADMIN_UIDS (comma-separated Supabase auth user IDs)
// and DATABASE_URL as Supabase secrets before deployment.
import postgres from "npm:postgres@3.4.5";

const reply = (value: unknown, status = 200) => new Response(JSON.stringify(value), {
  status, headers: { "content-type": "application/json", "cache-control": "no-store" },
});
Deno.serve(async (request) => {
  if (request.method !== "POST") return reply({ error: "method_not_allowed" }, 405);
  const bearer = request.headers.get("authorization") ?? "";
  const jwt = bearer.startsWith("Bearer ") ? bearer.slice(7) : "";
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const dbUrl = Deno.env.get("DATABASE_URL");
  const allow = (Deno.env.get("QAMVIO_LICENSE_ADMIN_UIDS") ?? "")
    .split(",").map((x) => x.trim()).filter(Boolean);
  if (!url || !anon || !dbUrl || allow.length === 0) {
    return reply({ error: "server_not_configured" }, 503);
  }
  const userResponse = await fetch(url + "/auth/v1/user", {
    headers: { authorization: "Bearer " + jwt, apikey: anon },
  });
  if (!userResponse.ok) return reply({ error: "unauthorized" }, 401);
  const user = await userResponse.json();
  if (!allow.includes(user.id)) return reply({ error: "forbidden" }, 403);
  let input: Record<string, unknown>;
  try { input = await request.json(); } catch { return reply({ error: "invalid_json" }, 400); }
  const sql = postgres(dbUrl, { max: 1, connect_timeout: 8 });
  try {
    if (input.action === "list") {
      const licenses = await sql`select id, customer_name, max_devices, expires_at, status, created_at from public.licenses order by created_at desc limit 100`;
      return reply({ licenses });
    }
    if (input.action === "revoke_device" && typeof input.device_id === "string") {
      const result = await sql`update public.license_devices set revoked_at=now()
        where id=${input.device_id}::uuid and revoked_at is null returning id`;
      return reply({ revoked: result.length === 1 });
    }
    if (input.action === "block" && typeof input.license_id === "string") {
      const result = await sql`update public.licenses set status='blocked'
        where id=${input.license_id}::uuid returning id`;
      return reply({ blocked: result.length === 1 });
    }
    return reply({ error: "unsupported_action" }, 400);
  } catch (_) {
    return reply({ error: "operation_failed" }, 503);
  } finally {
    await sql.end({ timeout: 2 });
  }
});
