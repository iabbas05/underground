-- Class booking, waitlist, notifications, no-show bans. Run once on an existing database
-- (after migrate_gate.sql and migrate_nfc.sql):
--   npx wrangler d1 execute ug-admin --remote --file=migrate_booking.sql
ALTER TABLE schedule ADD COLUMN capacity INTEGER NOT NULL DEFAULT 20;
ALTER TABLE members ADD COLUMN ban_until TEXT;
ALTER TABLE members ADD COLUMN strike_count INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS class_bookings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  member_id INTEGER NOT NULL REFERENCES members(id),
  schedule_id INTEGER NOT NULL REFERENCES schedule(id),
  class_date TEXT NOT NULL,           -- YYYY-MM-DD (Bahrain)
  class_time TEXT NOT NULL,           -- HH:MM
  status TEXT NOT NULL,               -- booked | waitlist | offered | cancelled | declined | expired | attended | no_show
  offer_expires_at TEXT,              -- Bahrain time "YYYY-MM-DD HH:MM:SS"
  reminded INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_cb_class ON class_bookings(schedule_id, class_date, status);
CREATE INDEX IF NOT EXISTS idx_cb_member ON class_bookings(member_id, class_date);

CREATE TABLE IF NOT EXISTS notifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  member_id INTEGER NOT NULL REFERENCES members(id),
  kind TEXT NOT NULL,
  title_ar TEXT NOT NULL,
  title_en TEXT NOT NULL,
  body_ar TEXT NOT NULL,
  body_en TEXT NOT NULL,
  data TEXT,
  created_at TEXT NOT NULL,
  read_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_notif_member ON notifications(member_id, id);
