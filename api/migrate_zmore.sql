-- Announcements, uploaded product pictures, and recovery packages (session credits).
--   npx wrangler d1 execute ug-admin --remote --file=migrate_zmore.sql
CREATE TABLE IF NOT EXISTS announcements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL, title_ar TEXT,
  body TEXT, body_ar TEXT,
  active INTEGER NOT NULL DEFAULT 1,
  expires TEXT,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS product_images (
  product_id INTEGER PRIMARY KEY REFERENCES products(id),
  data TEXT NOT NULL,                 -- base64 JPEG
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS recovery_packages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL,                 -- sauna | massage
  name TEXT NOT NULL, name_ar TEXT NOT NULL,
  sessions INTEGER NOT NULL,
  price REAL NOT NULL,
  valid_days INTEGER NOT NULL DEFAULT 90,
  active INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS account_credits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id INTEGER NOT NULL REFERENCES accounts(id),
  kind TEXT NOT NULL,
  package_id INTEGER,
  total INTEGER NOT NULL,
  used INTEGER NOT NULL DEFAULT 0,
  expires TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_credits_acc ON account_credits(account_id, kind);
ALTER TABLE recovery_bookings ADD COLUMN credit_id INTEGER;
INSERT INTO recovery_packages (kind,name,name_ar,sessions,price,valid_days) VALUES
 ('massage','Massage x5','مساج 5 جلسات',5,65,90),
 ('massage','Massage x10','مساج 10 جلسات',10,120,120),
 ('sauna','Sauna x5','ساونا 5 جلسات',5,20,90),
 ('sauna','Sauna x10','ساونا 10 جلسات',10,35,120);
INSERT INTO announcements (title,title_ar,body,body_ar,created_at) VALUES
 ('Welcome to the new UNDERGROUND app','أهلاً بك في تطبيق UNDERGROUND الجديد','Book classes, order healthy meals, and book sauna or massage right from the app.','احجز حصصك واطلب وجباتك الصحية واحجز الساونا والمساج من التطبيق مباشرة.','2026-10-30 00:00');
