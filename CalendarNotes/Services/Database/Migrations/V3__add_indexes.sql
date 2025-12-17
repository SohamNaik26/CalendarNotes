-- Migration V3: Add Additional Indexes
-- This migration adds performance indexes for common query patterns
-- Applied: Optimizes query performance

-- Additional indexes for calendar events
CREATE INDEX IF NOT EXISTS idx_calendar_events_category ON calendarnotes.calendar_events(category) WHERE category IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_calendar_events_recurring ON calendarnotes.calendar_events(is_recurring) WHERE is_recurring = TRUE;

-- Additional indexes for notes
CREATE INDEX IF NOT EXISTS idx_notes_updated_at ON calendarnotes.notes(updated_at DESC);

-- Additional indexes for todo items
CREATE INDEX IF NOT EXISTS idx_todo_items_priority ON calendarnotes.todo_items(priority);
CREATE INDEX IF NOT EXISTS idx_todo_items_user_priority ON calendarnotes.todo_items(user_id, priority, is_completed);

-- Additional indexes for bookmarks
CREATE INDEX IF NOT EXISTS idx_bookmarks_created_at ON calendarnotes.bookmarks(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_favorite ON calendarnotes.bookmarks(user_id, is_favorite) WHERE is_favorite = TRUE;

-- Additional indexes for collections
CREATE INDEX IF NOT EXISTS idx_collections_name ON calendarnotes.collections(name);

-- Composite index for sync log
CREATE INDEX IF NOT EXISTS idx_sync_log_user_status ON calendarnotes.sync_log(user_id, status, synced_at DESC);

