-- Rollback Migration V2: Remove Voice Notes Table
-- This migration reverses V2__add_voice_notes.sql

-- Drop trigger
DROP TRIGGER IF EXISTS update_voice_notes_updated_at ON calendarnotes.voice_notes;

-- Drop indexes
DROP INDEX IF EXISTS calendarnotes.idx_voice_notes_deleted_at;
DROP INDEX IF EXISTS calendarnotes.idx_voice_notes_fulltext;
DROP INDEX IF EXISTS calendarnotes.idx_voice_notes_created_at;
DROP INDEX IF EXISTS calendarnotes.idx_voice_notes_user_id;

-- Drop table
DROP TABLE IF EXISTS calendarnotes.voice_notes;

