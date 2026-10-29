-- UNDERGROUND admin database (Cloudflare D1 / SQLite)
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS branches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  name_ar TEXT NOT NULL,
  kind TEXT NOT NULL DEFAULT 'gym' -- gym | recovery
);

CREATE TABLE IF NOT EXISTS plans (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  name_ar TEXT NOT NULL,
  price REAL NOT NULL,
  months INTEGER NOT NULL,           -- 0 = single-day trial
  active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  username TEXT NOT NULL UNIQUE,
  pass_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin','staff')),
  branch_id INTEGER REFERENCES branches(id),
  base_salary REAL NOT NULL DEFAULT 0,
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS members (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  branch_id INTEGER NOT NULL REFERENCES branches(id),
  plan_id INTEGER REFERENCES plans(id),
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  created_by INTEGER REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_members_phone ON members(phone);
CREATE INDEX IF NOT EXISTS idx_members_name ON members(name);
CREATE INDEX IF NOT EXISTS idx_members_end ON members(end_date);

CREATE TABLE IF NOT EXISTS payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  member_id INTEGER REFERENCES members(id),
  branch_id INTEGER NOT NULL REFERENCES branches(id),
  amount REAL NOT NULL,
  method TEXT NOT NULL,              -- cash | card | benefit | transfer
  kind TEXT NOT NULL,                -- subscription | trial | recovery | nutrition | other
  note TEXT NOT NULL DEFAULT '',
  date TEXT NOT NULL,                -- YYYY-MM-DD (Bahrain)
  created_by INTEGER REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_payments_date ON payments(date);

CREATE TABLE IF NOT EXISTS expenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  branch_id INTEGER REFERENCES branches(id), -- NULL = general
  category TEXT NOT NULL,
  amount REAL NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  date TEXT NOT NULL,
  created_by INTEGER REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date);

CREATE TABLE IF NOT EXISTS attendance (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  branch_id INTEGER REFERENCES branches(id),
  date TEXT NOT NULL,
  clock_in TEXT NOT NULL,
  clock_out TEXT
);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance(date);

CREATE TABLE IF NOT EXISTS salaries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  month TEXT NOT NULL,               -- YYYY-MM
  amount REAL NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  date TEXT NOT NULL,
  created_by INTEGER REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_salaries_month ON salaries(month);

CREATE TABLE IF NOT EXISTS schedule (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  branch_id INTEGER NOT NULL REFERENCES branches(id),
  audience TEXT NOT NULL,            -- men | ladies
  day INTEGER NOT NULL,              -- 0 = Sunday ... 6 = Saturday
  time TEXT NOT NULL,                -- HH:MM 24h
  level TEXT NOT NULL                -- ba (beginners & advanced) | beast
);

-- Branches (ids 1-5 gym, 6-7 recovery)
INSERT INTO branches (id, name, name_ar, kind) VALUES
 (1,'Riffa','الرفاع','gym'),
 (2,'Janabiya','الجنبية','gym'),
 (3,'Hidd','الحد','gym'),
 (4,'Manama','المنامة','gym'),
 (5,'Isa Town','مدينة عيسى','gym'),
 (6,'Recovery - Janabiya Square','استشفاء - ساحة الجنبية','recovery'),
 (7,'Recovery - Bahrain Mall','استشفاء - بحرين مول','recovery');

-- Plans from the current membership offer (admin can edit prices in the app)
INSERT INTO plans (id, name, name_ar, price, months) VALUES
 (1,'Trial session','حصة تجريبية',5,0),
 (2,'1 month - Men working','شهر - رجال موظف',30,1),
 (3,'1 month - Men not working','شهر - رجال غير موظف',29,1),
 (4,'1 month - Ladies working','شهر - سيدات موظفة',27,1),
 (5,'1 month - Ladies not working','شهر - سيدات غير موظفة',26,1),
 (6,'3+1 months - Men','3+1 أشهر - رجال',99,4),
 (7,'3+1 months - Ladies','3+1 أشهر - سيدات',88,4),
 (8,'6+2 months','6+2 أشهر',165,8),
 (9,'1 year - 1 person','سنة - شخص واحد',264,12),
 (10,'1 year - 2 people (each)','سنة - شخصان (للفرد)',240,12),
 (11,'1 year - 3 people (each)','سنة - 3 أشخاص (للفرد)',216,12),
 (12,'1 year - 4 people (each)','سنة - 4 أشخاص (للفرد)',192,12),
 (13,'1 year - 5 people (each)','سنة - 5 أشخاص (للفرد)',168,12),
 (14,'University student - Men','طالب جامعة',29,1),
 (15,'University student - Ladies','طالبة جامعة',26,1),
 (16,'School student (under 18)','طالب مدرسة (أقل من 18)',22,1),
 (17,'Special rate (50% off)','سعر خاص (خصم 50%)',22,1),
 (18,'Cancer fighter (free for life)','محارب سرطان (مجاني مدى الحياة)',0,1200),
 (19,'1 month - regular (no offer)','شهر - سعر عادي',44,1);

-- gate + pass (also in migrate_gate.sql for existing databases)
-- NOTE: fresh installs: run schema.sql, then migrate_gate.sql.
