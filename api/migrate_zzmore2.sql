-- Class ratings, coupons, broadcasts, push device tokens.
--   npx wrangler d1 execute ug-admin --remote --file=migrate_zzmore2.sql
CREATE TABLE IF NOT EXISTS class_ratings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  booking_id INTEGER NOT NULL UNIQUE REFERENCES class_bookings(id),
  member_id INTEGER NOT NULL REFERENCES members(id),
  schedule_id INTEGER NOT NULL REFERENCES schedule(id),
  class_date TEXT NOT NULL,
  stars INTEGER NOT NULL,
  comment TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ratings_sched ON class_ratings(schedule_id);
CREATE TABLE IF NOT EXISTS coupons (
  code TEXT PRIMARY KEY,              -- stored upper-case
  kind TEXT NOT NULL,                 -- percent | amount
  value REAL NOT NULL,
  min_total REAL NOT NULL DEFAULT 0,
  max_uses INTEGER,                   -- NULL = unlimited
  used INTEGER NOT NULL DEFAULT 0,
  per_account INTEGER NOT NULL DEFAULT 1,
  expires TEXT,
  active INTEGER NOT NULL DEFAULT 1,
  note TEXT
);
ALTER TABLE orders ADD COLUMN discount REAL NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN coupon_code TEXT;
CREATE TABLE IF NOT EXISTS broadcasts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  segment TEXT NOT NULL,
  branch_id INTEGER,
  title_ar TEXT NOT NULL, title_en TEXT,
  body_ar TEXT NOT NULL, body_en TEXT,
  sent INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS device_tokens (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  token TEXT NOT NULL UNIQUE,
  account_id INTEGER,
  member_id INTEGER,
  platform TEXT NOT NULL DEFAULT 'android',
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_dt_member ON device_tokens(member_id);
CREATE INDEX IF NOT EXISTS idx_dt_acc ON device_tokens(account_id);
INSERT OR IGNORE INTO coupons (code,kind,value,min_total,max_uses,per_account,note) VALUES ('UG10','percent',10,1,200,1,'Sample: 10% off the first order');
