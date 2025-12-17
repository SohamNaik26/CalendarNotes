-- Rollback Migration V1: Remove Initial Schema
-- This migration reverses V1__initial_schema.sql
-- WARNING: This will delete all data!

-- Drop triggers
DROP TRIGGER IF EXISTS update_collections_updated_at ON calendarnotes.collections;
DROP TRIGGER IF EXISTS update_bookmarks_updated_at ON calendarnotes.bookmarks;
DROP TRIGGER IF EXISTS update_todo_items_updated_at ON calendarnotes.todo_items;
DROP TRIGGER IF EXISTS update_notes_updated_at ON calendarnotes.notes;
DROP TRIGGER IF EXISTS update_calendar_events_updated_at ON calendarnotes.calendar_events;
DROP TRIGGER IF EXISTS update_users_updated_at ON calendarnotes.users;

-- Drop function
DROP FUNCTION IF EXISTS calendarnotes.update_updated_at_column();

-- Drop indexes
DROP INDEX IF EXISTS calendarnotes.idx_sync_log_synced_at;
DROP INDEX IF EXISTS calendarnotes.idx_sync_log_entity;
DROP INDEX IF EXISTS calendarnotes.idx_sync_log_user_id;
DROP INDEX IF EXISTS calendarnotes.idx_collections_deleted_at;
DROP INDEX IF EXISTS calendarnotes.idx_collections_user_id;
DROP INDEX IF EXISTS calendarnotes.idx_bookmarks_deleted_at;
DROP INDEX IF EXISTS calendarnotes.idx_bookmarks_is_favorite;
DROP INDEX IF EXISTS calendarnotes.idx_bookmarks_tags;
DROP INDEX IF EXISTS calendarnotes.idx_bookmarks_url;
DROP INDEX IF EXISTS calendarnotes.idx_bookmarks_user_id;
DROP INDEX IF EXISTS calendarnotes.idx_todo_items_deleted_at;
DROP INDEX IF EXISTS calendarnotes.idx_todo_items_is_completed;
DROP INDEX IF EXISTS calendarnotes.idx_todo_items_due_date;
DROP INDEX IF EXISTS calendarnotes.idx_todo_items_user_id;
DROP INDEX IF EXISTS calendarnotes.idx_notes_deleted_at;
DROP INDEX IF EXISTS calendarnotes.idx_notes_fulltext;
DROP INDEX IF EXISTS calendarnotes.idx_notes_tags;
DROP INDEX IF EXISTS calendarnotes.idx_notes_created_at;
DROP INDEX IF EXISTS calendarnotes.idx_notes_user_id;
DROP INDEX IF EXISTS calendarnotes.idx_calendar_events_deleted_at;
DROP INDEX IF EXISTS calendarnotes.idx_calendar_events_date_range;
DROP INDEX IF EXISTS calendarnotes.idx_calendar_events_start_date;
DROP INDEX IF EXISTS calendarnotes.idx_calendar_events_user_id;
DROP INDEX IF EXISTS calendarnotes.idx_users_created_at;
DROP INDEX IF EXISTS calendarnotes.idx_users_email;

-- Drop tables
DROP TABLE IF EXISTS calendarnotes.sync_log;
DROP TABLE IF EXISTS calendarnotes.collections;
DROP TABLE IF EXISTS calendarnotes.bookmarks;
DROP TABLE IF EXISTS calendarnotes.todo_items;
DROP TABLE IF EXISTS calendarnotes.notes;
DROP TABLE IF EXISTS calendarnotes.calendar_events;
DROP TABLE IF EXISTS calendarnotes.users;

-- Drop schema (optional - comment out if you want to keep the schema)
-- DROP SCHEMA IF EXISTS calendarnotes CASCADE;

