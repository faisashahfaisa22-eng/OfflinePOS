package com.offlinepos.accounts;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

public final class NativeStore extends SQLiteOpenHelper {
    private static final String DB_NAME = "qamvio_native.db";
    private static final int DB_VERSION = 1;
    private static final String TABLE_KV = "kv_store";

    NativeStore(Context context) {
        super(context.getApplicationContext(), DB_NAME, null, DB_VERSION);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL(
                "CREATE TABLE " + TABLE_KV + " (" +
                        "k TEXT PRIMARY KEY NOT NULL," +
                        "v TEXT NOT NULL," +
                        "updated_at INTEGER NOT NULL" +
                        ")"
        );
        db.execSQL("CREATE INDEX idx_kv_updated_at ON " + TABLE_KV + "(updated_at)");
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        // Version 1 has no migrations yet. Future schema upgrades should be additive
        // so encrypted QAMVIO data is never destroyed automatically.
    }

    synchronized String get(String key) {
        if (key == null) return null;
        SQLiteDatabase db = getReadableDatabase();
        try (Cursor c = db.query(
                TABLE_KV,
                new String[]{"v"},
                "k=?",
                new String[]{key},
                null,
                null,
                null,
                "1"
        )) {
            return c.moveToFirst() ? c.getString(0) : null;
        }
    }

    synchronized boolean put(String key, String value) {
        if (key == null || value == null) return false;
        ContentValues values = new ContentValues();
        values.put("k", key);
        values.put("v", value);
        values.put("updated_at", System.currentTimeMillis());
        long result = getWritableDatabase().insertWithOnConflict(
                TABLE_KV,
                null,
                values,
                SQLiteDatabase.CONFLICT_REPLACE
        );
        return result != -1;
    }

    synchronized boolean remove(String key) {
        if (key == null) return false;
        getWritableDatabase().delete(TABLE_KV, "k=?", new String[]{key});
        return true;
    }

    synchronized boolean contains(String key) {
        if (key == null) return false;
        SQLiteDatabase db = getReadableDatabase();
        try (Cursor c = db.rawQuery(
                "SELECT 1 FROM " + TABLE_KV + " WHERE k=? LIMIT 1",
                new String[]{key}
        )) {
            return c.moveToFirst();
        }
    }

    synchronized int count() {
        SQLiteDatabase db = getReadableDatabase();
        try (Cursor c = db.rawQuery("SELECT COUNT(*) FROM " + TABLE_KV, null)) {
            return c.moveToFirst() ? c.getInt(0) : 0;
        }
    }

    synchronized void clearAll() {
        getWritableDatabase().delete(TABLE_KV, null, null);
    }
}
