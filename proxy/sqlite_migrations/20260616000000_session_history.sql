-- Session-history migration: makes sessions renameable and soft-deletable.
--
-- Columns are additive. SQLite has no `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`,
-- so the column adds themselves are applied idempotently from `trace::schema`
-- (see `add_column_if_missing`) before this file runs. The statements below are
-- all idempotent and safe to re-run on every boot:
--
--   sessions.name        TEXT      -- display name, defaulted for legacy rows
--   sessions.updated_at  INTEGER   -- epoch millis of the last rename, NULL until renamed
--   sessions.deleted_at  INTEGER   -- epoch millis of a soft delete, NULL while live
--
-- Active (non-deleted) sessions are listed newest-first; the partial index keeps
-- that scan cheap once a workspace accumulates many archived sessions.
CREATE INDEX IF NOT EXISTS idx_sessions_live_created_at
    ON sessions(created_at)
    WHERE deleted_at IS NULL;
