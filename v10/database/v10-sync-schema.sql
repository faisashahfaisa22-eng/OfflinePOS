-- POS & Accounts Pro v10 Sync Schema

CREATE TABLE sync_queue (
 id INTEGER PRIMARY KEY,
 action_type TEXT,
 payload TEXT,
 status TEXT DEFAULT 'pending',
 created_at TEXT
);

CREATE TABLE user_activity_log (
 id INTEGER PRIMARY KEY,
 user_id INTEGER,
 action TEXT,
 created_at TEXT
);
