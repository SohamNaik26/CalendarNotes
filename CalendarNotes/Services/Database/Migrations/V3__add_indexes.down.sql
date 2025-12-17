-- Rollback Migration V3: Remove Additional Indexes
-- This migration reverses V3__add_indexes.sql

-- Drop additional indexes
DROP INDEX IF EXISTS calendarnotes.idx_sync_log_user_status;
DROP INDEX IF EXISTS calendarnotes.idx_collections_name;
DROP INDEX IF EXISTS calendarnotes.idx_bookmarks_user_favorite;
DROP INDEX IF EXISTS calendarnotes.idx_bookmarks_created_at;
DROP INDEX IF EXISTS calendarnotes.idx_todo_items_user_priority;
DROP INDEX IF EXISTS calendarnotes.idx_todo_items_priority;
DROP INDEX IF EXISTS calendarnotes.idx_notes_updated_at;
DROP INDEX IF EXISTS calendarnotes.idx_calendar_events_recurring;
DROP INDEX IF EXISTS calendarnotes.idx_calendar_events_category;

