-- Recovery (sauna / massage) booking in 60-minute slots with per-branch capacity, plus BMI / progress entries.
--   npx wrangler d1 execute ug-admin --remote --file=migrate_recovery.sql
CREATE TABLE IF NOT EXISTS recovery_services (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  branch_id INTEGER NOT NULL REFERENCES branches(id),
  kind TEXT NOT NULL,                 -- sauna | massage
  capacity INTEGER NOT NULL DEFAULT 2,  -- people per slot, set by the admin
  open_time TEXT NOT NULL DEFAULT '09:00',
  close_time TEXT NOT NULL DEFAULT '22:00',
  slot_minutes INTEGER NOT NULL DEFAULT 60,
  price REAL,
  active INTEGER NOT NULL DEFAULT 1,
  UNIQUE (branch_id, kind)
);
CREATE TABLE IF NOT EXISTS recovery_bookings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id INTEGER NOT NULL REFERENCES accounts(id),
  service_id INTEGER NOT NULL REFERENCES recovery_services(id),
  date TEXT NOT NULL,
  time TEXT NOT NULL,                 -- HH:MM slot start
  status TEXT NOT NULL DEFAULT 'booked',   -- booked | cancelled | attended | no_show
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_rb_slot ON recovery_bookings(service_id, date, time, status);
CREATE INDEX IF NOT EXISTS idx_rb_acc ON recovery_bookings(account_id, date);

-- Sample setup for both recovery branches (6 = Janabiya Square, 7 = Bahrain Mall): edit capacity / hours / price in the back office
INSERT OR IGNORE INTO recovery_services (branch_id, kind, capacity, open_time, close_time, price) VALUES
 (6,'sauna',4,'09:00','22:00',5), (6,'massage',2,'09:00','22:00',15),
 (7,'sauna',4,'10:00','22:00',5), (7,'massage',2,'10:00','22:00',15);

CREATE TABLE IF NOT EXISTS body_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id INTEGER NOT NULL REFERENCES accounts(id),
  date TEXT NOT NULL,
  weight_kg REAL NOT NULL,
  height_cm REAL,
  body_fat REAL,
  waist_cm REAL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_body_acc ON body_entries(account_id, date);
