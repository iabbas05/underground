-- Gate + member pass. Run once on an existing database:
--   npx wrangler d1 execute ug-admin --remote --file=migrate_gate.sql
ALTER TABLE members ADD COLUMN blocked INTEGER NOT NULL DEFAULT 0;
ALTER TABLE members ADD COLUMN pass_ver INTEGER NOT NULL DEFAULT 1;

CREATE TABLE IF NOT EXISTS gate_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  member_id INTEGER REFERENCES members(id),
  branch_id INTEGER REFERENCES branches(id),
  gate TEXT NOT NULL DEFAULT '',
  result TEXT NOT NULL,          -- allowed | denied
  reason TEXT NOT NULL DEFAULT '',-- ok | expired | blocked | bad_code | old_pass | unknown
  method TEXT NOT NULL DEFAULT 'app', -- app (rotating code) | wallet (static code) | manual
  by_user INTEGER REFERENCES users(id),
  created_at TEXT NOT NULL      -- Bahrain time "YYYY-MM-DD HH:MM"
);
CREATE INDEX IF NOT EXISTS idx_gate_logs_time ON gate_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_gate_logs_member ON gate_logs(member_id);

CREATE TABLE IF NOT EXISTS gate_commands (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  branch_id INTEGER NOT NULL,
  created_by INTEGER,
  created_at TEXT NOT NULL,
  done INTEGER NOT NULL DEFAULT 0
);
