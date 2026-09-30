package com.offlinepos.accounts;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

public final class NativeCloudBackupWorker extends Worker {
    private static final String PROJECT_URL = "https://noosoaxtwiacbmrjaugh.supabase.co";
    private static final String PUBLISHABLE_KEY = "sb_publishable_ZVWWnnhsabhe-LwZPQwffg_Gz1QMxDy";
    private static final String TABLE = "qamvio_cloud_backups";

    private static final String KEY = "offline_pos_accounts_pro_v2";
    private static final String AUTH_KEY = KEY + "_auth_users_v2";
    private static final String DB_META_KEY = KEY + "_meta_v16";
    private static final String INTEGRITY_KEY = KEY + "_integrity_v16";
    private static final String CLOUD_SESSION_KEY = KEY + "_cloud_session_v1";
    private static final String CLOUD_LAST_SYNC_KEY = KEY + "_cloud_last_sync_v1";
    private static final String CLOUD_LAST_DAILY_KEY = KEY + "_cloud_last_daily_v1";
    private static final String CLOUD_BACKGROUND_STATUS_KEY = KEY + "_cloud_background_status_v1";

    private NativeStore store;

    public NativeCloudBackupWorker(@NonNull Context appContext, @NonNull WorkerParameters params) {
        super(appContext, params);
    }

    @NonNull
    @Override
    public Result doWork() {
        store = new NativeStore(getApplicationContext());
        try {
            String sessionRaw = store.get(CLOUD_SESSION_KEY);
            if (sessionRaw == null || sessionRaw.trim().isEmpty()) return Result.success();

            JSONObject session = new JSONObject(sessionRaw);
            String userId = session.optString("user_id", "");
            if (userId.isEmpty()) return Result.success();

            String dbRaw = store.get(KEY);
            String authRaw = store.get(AUTH_KEY);
            String metaRaw = store.get(DB_META_KEY);
            if (dbRaw == null || authRaw == null || metaRaw == null) return Result.success();

            session = ensureAccessToken(session);
            String token = session.optString("access_token", "");
            if (token.isEmpty()) return Result.retry();

            JSONObject dbBox = new JSONObject(dbRaw);
            String localCipher = dbBox.optString("ct", "");
            if (!safeToReplaceRemote(userId, token, localCipher.length())) {
                store.put(CLOUD_BACKGROUND_STATUS_KEY,
                        "Auto backup paused: cloud copy is larger than this device. Restore cloud data before replacing it.");
                return Result.success();
            }

            JSONObject payload = new JSONObject();
            payload.put("format", 2);
            payload.put("app", "QAMVIO POS");
            payload.put("encrypted", true);
            payload.put("db_box", dbBox);
            payload.put("auth_users", new JSONArray(authRaw));
            payload.put("db_meta", new JSONObject(metaRaw));
            String integrityRaw = store.get(INTEGRITY_KEY);
            if (integrityRaw != null && !integrityRaw.trim().isEmpty()) {
                payload.put("integrity", new JSONObject(integrityRaw));
            }
            payload.put("synced_at", nowIso());

            JSONObject row = new JSONObject();
            row.put("user_id", userId);
            row.put("payload", payload);
            row.put("updated_at", nowIso());

            int code = upload(row, token);
            if (code == 401 || code == 403) {
                session = refreshSession(session);
                token = session.optString("access_token", "");
                code = upload(row, token);
            }

            if (code >= 200 && code < 300) {
                String now = nowIso();
                store.put(CLOUD_LAST_SYNC_KEY, now);
                store.put(CLOUD_LAST_DAILY_KEY, now);
                store.put(CLOUD_BACKGROUND_STATUS_KEY, "Daily encrypted cloud backup completed: " + now);
                return Result.success();
            }
            store.put(CLOUD_BACKGROUND_STATUS_KEY, "Daily cloud backup HTTP " + code);
            return code >= 500 ? Result.retry() : Result.failure();
        } catch (Exception e) {
            try {
                store.put(CLOUD_BACKGROUND_STATUS_KEY, "Daily cloud backup failed: " + e.getMessage());
            } catch (Exception ignored) {}
            return Result.retry();
        } finally {
            if (store != null) store.close();
        }
    }

    private JSONObject ensureAccessToken(JSONObject session) throws Exception {
        long expiresAt = session.optLong("expires_at", 0L);
        String access = session.optString("access_token", "");
        if (!access.isEmpty() && (expiresAt == 0L || expiresAt > System.currentTimeMillis() + 60_000L)) {
            return session;
        }
        return refreshSession(session);
    }

    private JSONObject refreshSession(JSONObject session) throws Exception {
        String refreshToken = session.optString("refresh_token", "");
        if (refreshToken.isEmpty()) throw new IllegalStateException("Cloud refresh token is missing.");

        JSONObject body = new JSONObject();
        body.put("refresh_token", refreshToken);
        HttpResponse r = request(
                PROJECT_URL + "/auth/v1/token?grant_type=refresh_token",
                "POST",
                PUBLISHABLE_KEY,
                null,
                body.toString()
        );
        if (r.code < 200 || r.code >= 300) throw new IllegalStateException("Cloud session refresh failed: HTTP " + r.code);

        JSONObject data = new JSONObject(r.body);
        JSONObject updated = new JSONObject(session.toString());
        updated.put("access_token", data.optString("access_token", ""));
        if (!data.optString("refresh_token", "").isEmpty()) updated.put("refresh_token", data.optString("refresh_token"));
        long expiresIn = Math.max(60L, data.optLong("expires_in", 3600L));
        updated.put("expires_at", System.currentTimeMillis() + expiresIn * 1000L);
        JSONObject user = data.optJSONObject("user");
        if (user != null && updated.optString("user_id", "").isEmpty()) updated.put("user_id", user.optString("id", ""));
        store.put(CLOUD_SESSION_KEY, updated.toString());
        return updated;
    }

    private boolean safeToReplaceRemote(String userId, String token, int localCipherLength) {
        try {
            String path = PROJECT_URL + "/rest/v1/" + TABLE
                    + "?user_id=eq." + java.net.URLEncoder.encode(userId, "UTF-8")
                    + "&select=payload,updated_at&limit=1";
            HttpResponse r = request(path, "GET", PUBLISHABLE_KEY, token, null);
            if (r.code < 200 || r.code >= 300) return true;
            JSONArray rows = new JSONArray(r.body);
            if (rows.length() == 0) return true;
            JSONObject payload = rows.getJSONObject(0).optJSONObject("payload");
            if (payload == null) return true;
            JSONObject remoteBox = payload.optJSONObject("db_box");
            if (remoteBox == null) return true;
            int remoteCipherLength = remoteBox.optString("ct", "").length();
            if (remoteCipherLength > 2000 && localCipherLength > 0 && remoteCipherLength > localCipherLength * 1.30) {
                return false;
            }
        } catch (Exception ignored) {}
        return true;
    }

    private int upload(JSONObject row, String token) throws Exception {
        String path = PROJECT_URL + "/rest/v1/" + TABLE + "?on_conflict=user_id";
        HttpURLConnection c = (HttpURLConnection) new URL(path).openConnection();
        c.setConnectTimeout(20_000);
        c.setReadTimeout(30_000);
        c.setRequestMethod("POST");
        c.setDoOutput(true);
        c.setRequestProperty("apikey", PUBLISHABLE_KEY);
        c.setRequestProperty("Authorization", "Bearer " + token);
        c.setRequestProperty("Content-Type", "application/json");
        c.setRequestProperty("Prefer", "resolution=merge-duplicates");
        byte[] bytes = row.toString().getBytes(StandardCharsets.UTF_8);
        try (OutputStream out = c.getOutputStream()) {
            out.write(bytes);
        }
        int code = c.getResponseCode();
        closeQuietly(code >= 400 ? c.getErrorStream() : c.getInputStream());
        c.disconnect();
        return code;
    }

    private HttpResponse request(String url, String method, String apiKey, String bearer, String body) throws Exception {
        HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection();
        c.setConnectTimeout(20_000);
        c.setReadTimeout(30_000);
        c.setRequestMethod(method);
        c.setRequestProperty("apikey", apiKey);
        if (bearer != null && !bearer.isEmpty()) c.setRequestProperty("Authorization", "Bearer " + bearer);
        if (body != null) {
            c.setDoOutput(true);
            c.setRequestProperty("Content-Type", "application/json");
            try (OutputStream out = c.getOutputStream()) {
                out.write(body.getBytes(StandardCharsets.UTF_8));
            }
        }
        int code = c.getResponseCode();
        String responseBody = readAll(code >= 400 ? c.getErrorStream() : c.getInputStream());
        c.disconnect();
        return new HttpResponse(code, responseBody);
    }

    private static String readAll(InputStream in) throws Exception {
        if (in == null) return "";
        StringBuilder sb = new StringBuilder();
        try (BufferedReader br = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
            String line;
            while ((line = br.readLine()) != null) sb.append(line);
        }
        return sb.toString();
    }

    private static void closeQuietly(InputStream in) {
        if (in == null) return;
        try { in.close(); } catch (Exception ignored) {}
    }

    private static String nowIso() {
        SimpleDateFormat f = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US);
        f.setTimeZone(TimeZone.getTimeZone("UTC"));
        return f.format(new Date());
    }

    private static final class HttpResponse {
        final int code;
        final String body;
        HttpResponse(int code, String body) {
            this.code = code;
            this.body = body == null ? "" : body;
        }
    }
}
