-- Customer accounts (username + password), admin activation / linking to members, and branch details.
-- Run once on an existing database:
--   npx wrangler d1 execute ug-admin --remote --file=migrate_accounts.sql
CREATE TABLE IF NOT EXISTS accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,      -- lowercase
  name TEXT NOT NULL,
  phone TEXT NOT NULL,                -- digits only
  email TEXT,
  email_verified INTEGER NOT NULL DEFAULT 0,
  password_hash TEXT NOT NULL,
  member_id INTEGER REFERENCES members(id),   -- set when linked to a real subscriber
  status TEXT NOT NULL DEFAULT 'pending',     -- pending | active | disabled
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_acc_phone ON accounts(phone);
CREATE INDEX IF NOT EXISTS idx_acc_member ON accounts(member_id);

CREATE TABLE IF NOT EXISTS link_codes (
  code TEXT PRIMARY KEY,              -- 6 digits, given to the member by staff
  member_id INTEGER NOT NULL REFERENCES members(id),
  expires_at TEXT NOT NULL            -- Bahrain time "YYYY-MM-DD HH:MM"
);

CREATE TABLE IF NOT EXISTS email_otps (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id INTEGER NOT NULL REFERENCES accounts(id),
  code_hash TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  tries INTEGER NOT NULL DEFAULT 0
);

ALTER TABLE branches ADD COLUMN address TEXT;
ALTER TABLE branches ADD COLUMN address_ar TEXT;
ALTER TABLE branches ADD COLUMN hours TEXT;
ALTER TABLE branches ADD COLUMN hours_ar TEXT;
ALTER TABLE branches ADD COLUMN phone TEXT;
ALTER TABLE branches ADD COLUMN map_url TEXT;
