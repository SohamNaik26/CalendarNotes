-- CalendarNotes Database Initialization Script
-- This script runs automatically when the database container is first created

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS calendarnotes;

-- Set search path
SET search_path TO calendarnotes, public;

-- ============================================
-- TABLES
-- ============================================

-- 1. Users table
CREATE TABLE IF NOT EXISTS calendarnotes.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    profile_image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP WITH TIME ZONE,
    email_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE
);

-- 2. Calendar events table
CREATE TABLE IF NOT EXISTS calendarnotes.calendar_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES calendarnotes.users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    location VARCHAR(255),
    category VARCHAR(100),
    color VARCHAR(7),
    is_all_day BOOLEAN DEFAULT FALSE,
    is_recurring BOOLEAN DEFAULT FALSE,
    recurrence_rule JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    synced_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT valid_date_range CHECK (end_date >= start_date)
);

-- 3. Notes table
CREATE TABLE IF NOT EXISTS calendarnotes.notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES calendarnotes.users(id) ON DELETE CASCADE,
    title VARCHAR(255),
    content TEXT,
    rich_content JSONB,
    linked_date DATE,
    linked_event_id UUID REFERENCES calendarnotes.calendar_events(id) ON DELETE SET NULL,
    tags TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    synced_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- 4. Todo items table
CREATE TABLE IF NOT EXISTS calendarnotes.todo_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES calendarnotes.users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    due_date TIMESTAMP WITH TIME ZONE,
    priority VARCHAR(20) CHECK(priority IN ('high', 'medium', 'low')),
    category VARCHAR(100),
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP WITH TIME ZONE,
    is_recurring BOOLEAN DEFAULT FALSE,
    recurrence_rule JSONB,
    linked_event_id UUID REFERENCES calendarnotes.calendar_events(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    synced_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- 5. Collections table (created before bookmarks due to foreign key reference)
CREATE TABLE IF NOT EXISTS calendarnotes.collections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES calendarnotes.users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    color VARCHAR(7),
    icon VARCHAR(50),
    parent_collection_id UUID REFERENCES calendarnotes.collections(id) ON DELETE CASCADE,
    sort_order INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    synced_at TIMESTAMP WITH TIME ZONE
);

-- 6. Bookmarks table
CREATE TABLE IF NOT EXISTS calendarnotes.bookmarks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES calendarnotes.users(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    favicon_url TEXT,
    preview_image_url TEXT,
    tags TEXT[],
    collection_id UUID REFERENCES calendarnotes.collections(id) ON DELETE SET NULL,
    is_favorite BOOLEAN DEFAULT FALSE,
    is_archived BOOLEAN DEFAULT FALSE,
    open_count INTEGER DEFAULT 0,
    last_opened_at TIMESTAMP WITH TIME ZONE,
    linked_date DATE,
    linked_event_id UUID REFERENCES calendarnotes.calendar_events(id) ON DELETE SET NULL,
    linked_note_id UUID REFERENCES calendarnotes.notes(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    synced_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- 7. Voice notes table
CREATE TABLE IF NOT EXISTS calendarnotes.voice_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES calendarnotes.users(id) ON DELETE CASCADE,
    audio_file_path TEXT NOT NULL,
    transcription TEXT,
    duration_seconds INTEGER,
    file_size_bytes BIGINT,
    bitrate_kbps INTEGER,
    sample_rate_hz INTEGER,
    linked_note_id UUID REFERENCES calendarnotes.notes(id) ON DELETE SET NULL,
    linked_event_id UUID REFERENCES calendarnotes.calendar_events(id) ON DELETE SET NULL,
    linked_task_id UUID REFERENCES calendarnotes.todo_items(id) ON DELETE SET NULL,
    is_favorite BOOLEAN DEFAULT FALSE,
    is_archived BOOLEAN DEFAULT FALSE,
    auto_delete_after_days INTEGER,
    auto_delete_on TIMESTAMP WITH TIME ZONE,
    cloud_storage_url TEXT,
    cloud_sync_status VARCHAR(50) DEFAULT 'pending',
    is_offline_available BOOLEAN DEFAULT TRUE,
    compression_status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    synced_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- 8. Sync log table
CREATE TABLE IF NOT EXISTS calendarnotes.sync_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES calendarnotes.users(id) ON DELETE CASCADE,
    device_id VARCHAR(255) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID NOT NULL,
    action VARCHAR(20) CHECK(action IN ('create', 'update', 'delete')),
    synced_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    sync_status VARCHAR(50) DEFAULT 'pending'
);

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================

-- Users indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON calendarnotes.users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON calendarnotes.users(created_at);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON calendarnotes.users(is_active);

-- Calendar events indexes
CREATE INDEX IF NOT EXISTS idx_calendar_events_user_id_start_end ON calendarnotes.calendar_events(user_id, start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_calendar_events_user_id ON calendarnotes.calendar_events(user_id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_start_date ON calendarnotes.calendar_events(start_date);
CREATE INDEX IF NOT EXISTS idx_calendar_events_end_date ON calendarnotes.calendar_events(end_date);
CREATE INDEX IF NOT EXISTS idx_calendar_events_deleted_at ON calendarnotes.calendar_events(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_calendar_events_date_range ON calendarnotes.calendar_events USING GIST (tstzrange(start_date, end_date));

-- Notes indexes
CREATE INDEX IF NOT EXISTS idx_notes_user_id_linked_date ON calendarnotes.notes(user_id, linked_date);
CREATE INDEX IF NOT EXISTS idx_notes_user_id ON calendarnotes.notes(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_linked_date ON calendarnotes.notes(linked_date);
CREATE INDEX IF NOT EXISTS idx_notes_linked_event_id ON calendarnotes.notes(linked_event_id);
CREATE INDEX IF NOT EXISTS idx_notes_deleted_at ON calendarnotes.notes(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_notes_tags ON calendarnotes.notes USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_notes_title_search ON calendarnotes.notes USING gin(to_tsvector('english', COALESCE(title, '')));
CREATE INDEX IF NOT EXISTS idx_notes_content_search ON calendarnotes.notes USING gin(to_tsvector('english', COALESCE(content, '')));

-- Todo items indexes
CREATE INDEX IF NOT EXISTS idx_todo_items_user_id_due_date_completed ON calendarnotes.todo_items(user_id, due_date, is_completed);
CREATE INDEX IF NOT EXISTS idx_todo_items_user_id ON calendarnotes.todo_items(user_id);
CREATE INDEX IF NOT EXISTS idx_todo_items_due_date ON calendarnotes.todo_items(due_date);
CREATE INDEX IF NOT EXISTS idx_todo_items_is_completed ON calendarnotes.todo_items(is_completed);
CREATE INDEX IF NOT EXISTS idx_todo_items_linked_event_id ON calendarnotes.todo_items(linked_event_id);
CREATE INDEX IF NOT EXISTS idx_todo_items_deleted_at ON calendarnotes.todo_items(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_todo_items_priority ON calendarnotes.todo_items(priority);

-- Collections indexes
CREATE INDEX IF NOT EXISTS idx_collections_user_id ON calendarnotes.collections(user_id);
CREATE INDEX IF NOT EXISTS idx_collections_parent_id ON calendarnotes.collections(parent_collection_id);
CREATE INDEX IF NOT EXISTS idx_collections_sort_order ON calendarnotes.collections(sort_order);

-- Bookmarks indexes
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_id_favorite_archived ON calendarnotes.bookmarks(user_id, is_favorite, is_archived);
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_id_url ON calendarnotes.bookmarks(user_id, url);
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_id ON calendarnotes.bookmarks(user_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_is_favorite ON calendarnotes.bookmarks(is_favorite);
CREATE INDEX IF NOT EXISTS idx_bookmarks_is_archived ON calendarnotes.bookmarks(is_archived);
CREATE INDEX IF NOT EXISTS idx_bookmarks_collection_id ON calendarnotes.bookmarks(collection_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_linked_event_id ON calendarnotes.bookmarks(linked_event_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_linked_note_id ON calendarnotes.bookmarks(linked_note_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_deleted_at ON calendarnotes.bookmarks(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_bookmarks_tags ON calendarnotes.bookmarks USING GIN(tags);

-- Voice notes indexes
CREATE INDEX IF NOT EXISTS idx_voice_notes_user_id ON calendarnotes.voice_notes(user_id);
CREATE INDEX IF NOT EXISTS idx_voice_notes_linked_note_id ON calendarnotes.voice_notes(linked_note_id);
CREATE INDEX IF NOT EXISTS idx_voice_notes_linked_event_id ON calendarnotes.voice_notes(linked_event_id);
CREATE INDEX IF NOT EXISTS idx_voice_notes_linked_task_id ON calendarnotes.voice_notes(linked_task_id);
CREATE INDEX IF NOT EXISTS idx_voice_notes_deleted_at ON calendarnotes.voice_notes(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_voice_notes_created_at ON calendarnotes.voice_notes(created_at);
CREATE INDEX IF NOT EXISTS idx_voice_notes_is_favorite ON calendarnotes.voice_notes(is_favorite) WHERE is_favorite = TRUE;
CREATE INDEX IF NOT EXISTS idx_voice_notes_auto_delete_on ON calendarnotes.voice_notes(auto_delete_on) WHERE auto_delete_on IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_voice_notes_cloud_sync_status ON calendarnotes.voice_notes(cloud_sync_status);
CREATE INDEX IF NOT EXISTS idx_voice_notes_transcription_search ON calendarnotes.voice_notes USING gin(to_tsvector('english', COALESCE(transcription, '')));

-- Sync log indexes
CREATE INDEX IF NOT EXISTS idx_sync_log_user_id_synced_at ON calendarnotes.sync_log(user_id, synced_at);
CREATE INDEX IF NOT EXISTS idx_sync_log_user_id ON calendarnotes.sync_log(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_log_synced_at ON calendarnotes.sync_log(synced_at);
CREATE INDEX IF NOT EXISTS idx_sync_log_entity_type_id ON calendarnotes.sync_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_sync_log_sync_status ON calendarnotes.sync_log(sync_status);
CREATE INDEX IF NOT EXISTS idx_sync_log_device_id ON calendarnotes.sync_log(device_id);

-- 9. Offline operations table for robust offline queue processing
CREATE TABLE IF NOT EXISTS calendarnotes.offline_operations (
    id UUID PRIMARY KEY,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    operation_type TEXT NOT NULL CHECK (operation_type IN ('create','update','delete')),
    payload JSONB,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_attempt_at TIMESTAMP WITH TIME ZONE,
    status TEXT NOT NULL CHECK (status IN ('pending','processing','failed','completed')) DEFAULT 'pending'
);

-- Index to quickly fetch pending operations
CREATE INDEX IF NOT EXISTS idx_offline_operations_status_created_at
    ON calendarnotes.offline_operations (status, created_at);

-- ============================================
-- TRIGGERS FOR TIMESTAMPS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION calendarnotes.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for users table
DROP TRIGGER IF EXISTS update_users_updated_at ON calendarnotes.users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON calendarnotes.users
    FOR EACH ROW
    EXECUTE FUNCTION calendarnotes.update_updated_at_column();

-- Trigger for calendar_events table
DROP TRIGGER IF EXISTS update_calendar_events_updated_at ON calendarnotes.calendar_events;
CREATE TRIGGER update_calendar_events_updated_at
    BEFORE UPDATE ON calendarnotes.calendar_events
    FOR EACH ROW
    EXECUTE FUNCTION calendarnotes.update_updated_at_column();

-- Trigger for notes table
DROP TRIGGER IF EXISTS update_notes_updated_at ON calendarnotes.notes;
CREATE TRIGGER update_notes_updated_at
    BEFORE UPDATE ON calendarnotes.notes
    FOR EACH ROW
    EXECUTE FUNCTION calendarnotes.update_updated_at_column();

-- Trigger for todo_items table
DROP TRIGGER IF EXISTS update_todo_items_updated_at ON calendarnotes.todo_items;
CREATE TRIGGER update_todo_items_updated_at
    BEFORE UPDATE ON calendarnotes.todo_items
    FOR EACH ROW
    EXECUTE FUNCTION calendarnotes.update_updated_at_column();

-- Trigger for collections table
DROP TRIGGER IF EXISTS update_collections_updated_at ON calendarnotes.collections;
CREATE TRIGGER update_collections_updated_at
    BEFORE UPDATE ON calendarnotes.collections
    FOR EACH ROW
    EXECUTE FUNCTION calendarnotes.update_updated_at_column();

-- Trigger for bookmarks table
DROP TRIGGER IF EXISTS update_bookmarks_updated_at ON calendarnotes.bookmarks;
CREATE TRIGGER update_bookmarks_updated_at
    BEFORE UPDATE ON calendarnotes.bookmarks
    FOR EACH ROW
    EXECUTE FUNCTION calendarnotes.update_updated_at_column();

-- ============================================
-- TRIGGERS FOR SOFT DELETE
-- ============================================

-- Function for soft delete (sets deleted_at instead of actual delete)
CREATE OR REPLACE FUNCTION calendarnotes.soft_delete()
RETURNS TRIGGER AS $$
BEGIN
    -- Instead of deleting, set deleted_at timestamp
    NEW.deleted_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a view function to handle DELETE operations as soft deletes
-- Note: PostgreSQL doesn't support INSTEAD OF triggers on tables, only views
-- So we'll create a function that can be called instead of DELETE

-- Function to perform soft delete on calendar_events
CREATE OR REPLACE FUNCTION calendarnotes.soft_delete_calendar_event(event_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE calendarnotes.calendar_events
    SET deleted_at = CURRENT_TIMESTAMP
    WHERE id = event_id AND deleted_at IS NULL;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to perform soft delete on notes
CREATE OR REPLACE FUNCTION calendarnotes.soft_delete_note(note_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE calendarnotes.notes
    SET deleted_at = CURRENT_TIMESTAMP
    WHERE id = note_id AND deleted_at IS NULL;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to perform soft delete on todo_items
CREATE OR REPLACE FUNCTION calendarnotes.soft_delete_todo_item(todo_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE calendarnotes.todo_items
    SET deleted_at = CURRENT_TIMESTAMP
    WHERE id = todo_id AND deleted_at IS NULL;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to perform soft delete on bookmarks
CREATE OR REPLACE FUNCTION calendarnotes.soft_delete_bookmark(bookmark_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE calendarnotes.bookmarks
    SET deleted_at = CURRENT_TIMESTAMP
    WHERE id = bookmark_id AND deleted_at IS NULL;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to perform soft delete on voice_notes
CREATE OR REPLACE FUNCTION calendarnotes.soft_delete_voice_note(voice_note_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE calendarnotes.voice_notes
    SET deleted_at = CURRENT_TIMESTAMP
    WHERE id = voice_note_id AND deleted_at IS NULL;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Function to restore soft-deleted records
CREATE OR REPLACE FUNCTION calendarnotes.restore_calendar_event(event_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE calendarnotes.calendar_events
    SET deleted_at = NULL
    WHERE id = event_id AND deleted_at IS NOT NULL;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calendarnotes.restore_note(note_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE calendarnotes.notes
    SET deleted_at = NULL
    WHERE id = note_id AND deleted_at IS NOT NULL;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calendarnotes.restore_todo_item(todo_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE calendarnotes.todo_items
    SET deleted_at = NULL
    WHERE id = todo_id AND deleted_at IS NOT NULL;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calendarnotes.restore_bookmark(bookmark_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE calendarnotes.bookmarks
    SET deleted_at = NULL
    WHERE id = bookmark_id AND deleted_at IS NOT NULL;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calendarnotes.restore_voice_note(voice_note_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE calendarnotes.voice_notes
    SET deleted_at = NULL
    WHERE id = voice_note_id AND deleted_at IS NOT NULL;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Trigger for voice_notes updated_at
DROP TRIGGER IF EXISTS update_voice_notes_updated_at ON calendarnotes.voice_notes;
CREATE TRIGGER update_voice_notes_updated_at
    BEFORE UPDATE ON calendarnotes.voice_notes
    FOR EACH ROW
    EXECUTE FUNCTION calendarnotes.update_updated_at_column();

-- ============================================
-- INITIAL DATA (Optional)
-- ============================================

-- You can add initial seed data here if needed
-- Example:
-- INSERT INTO calendarnotes.users (email, password_hash, full_name, email_verified) 
-- VALUES ('admin@example.com', 'hashed_password_here', 'Admin User', TRUE)
-- ON CONFLICT (email) DO NOTHING;

-- ============================================
-- GRANTS (if using separate database user)
-- ============================================

-- Grant permissions to the database user
GRANT ALL PRIVILEGES ON SCHEMA calendarnotes TO calendarnotes_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA calendarnotes TO calendarnotes_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA calendarnotes TO calendarnotes_user;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA calendarnotes TO calendarnotes_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA calendarnotes GRANT ALL ON TABLES TO calendarnotes_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA calendarnotes GRANT ALL ON SEQUENCES TO calendarnotes_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA calendarnotes GRANT ALL ON FUNCTIONS TO calendarnotes_user;
