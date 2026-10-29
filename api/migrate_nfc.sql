-- NFC member cards. Run once on an existing database (after migrate_gate.sql):
--   npx wrangler d1 execute ug-admin --remote --file=migrate_nfc.sql
ALTER TABLE members ADD COLUMN nfc_uid TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_members_nfc ON members(nfc_uid) WHERE nfc_uid IS NOT NULL;
