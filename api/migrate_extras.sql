-- Membership freeze on request, monthly challenges, automatic notices.
--   npx wrangler d1 execute ug-admin --remote --file=migrate_extras.sql
ALTER TABLE members ADD COLUMN frozen_until TEXT;
CREATE TABLE IF NOT EXISTS freeze_requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  member_id INTEGER NOT NULL REFERENCES members(id),
  account_id INTEGER NOT NULL REFERENCES accounts(id),
  days INTEGER NOT NULL,
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'pending',   -- pending | approved | rejected
  created_at TEXT NOT NULL,
  decided_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_freeze_member ON freeze_requests(member_id, status);
CREATE TABLE IF NOT EXISTS challenges (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL, title_ar TEXT NOT NULL,
  metric TEXT NOT NULL,                      -- visits | classes
  target INTEGER NOT NULL,
  month TEXT NOT NULL,                       -- YYYY-MM
  active INTEGER NOT NULL DEFAULT 1
);
