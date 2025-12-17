-- Migration V1: Initial Schema
-- This migration creates the initial database schema for CalendarNotes
-- Applied: Initial setup

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
    priority VARCHAR(20) DEFAULT 'medium',
    is_completed BOOLEAN DEFAULT FALSE,
    due_date TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    synced_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- 5. Bookmarks table
CREATE TABLE IF NOT EXISTS calendarnotes.bookmarks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES calendarnotes.users(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    title VARCHAR(255),
    description TEXT,
    tags TEXT[],
    is_favorite BOOLEAN DEFAULT FALSE,
    is_archived BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    synced_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- 6. Collections table
CREATE TABLE IF NOT EXISTS calendarnotes.collections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES calendarnotes.users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    color VARCHAR(7),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- 7. Sync log table
CREATE TABLE IF NOT EXISTS calendarnotes.sync_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES calendarnotes.users(id) ON DELETE CASCADE,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    action VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL,
    error_message TEXT,
    synced_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- INDEXES
-- ============================================

-- Users indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON calendarnotes.users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON calendarnotes.users(created_at);

-- Calendar events indexes
CREATE INDEX IF NOT EXISTS idx_calendar_events_user_id ON calendarnotes.calendar_events(user_id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_start_date ON calendarnotes.calendar_events(start_date);
CREATE INDEX IF NOT EXISTS idx_calendar_events_date_range ON calendarnotes.calendar_events USING GIST (tstzrange(start_date, end_date));
CREATE INDEX IF NOT EXISTS idx_calendar_events_deleted_at ON calendarnotes.calendar_events(deleted_at) WHERE deleted_at IS NULL;

-- Notes indexes
CREATE INDEX IF NOT EXISTS idx_notes_user_id ON calendarnotes.notes(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_created_at ON calendarnotes.notes(created_at);
CREATE INDEX IF NOT EXISTS idx_notes_tags ON calendarnotes.notes USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_notes_fulltext ON calendarnotes.notes USING GIN(to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(content, '')));
CREATE INDEX IF NOT EXISTS idx_notes_deleted_at ON calendarnotes.notes(deleted_at) WHERE deleted_at IS NULL;

-- Todo items indexes
CREATE INDEX IF NOT EXISTS idx_todo_items_user_id ON calendarnotes.todo_items(user_id);
CREATE INDEX IF NOT EXISTS idx_todo_items_due_date ON calendarnotes.todo_items(due_date);
CREATE INDEX IF NOT EXISTS idx_todo_items_is_completed ON calendarnotes.todo_items(is_completed);
CREATE INDEX IF NOT EXISTS idx_todo_items_deleted_at ON calendarnotes.todo_items(deleted_at) WHERE deleted_at IS NULL;

-- Bookmarks indexes
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_id ON calendarnotes.bookmarks(user_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_url ON calendarnotes.bookmarks(url);
CREATE INDEX IF NOT EXISTS idx_bookmarks_tags ON calendarnotes.bookmarks USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_bookmarks_is_favorite ON calendarnotes.bookmarks(is_favorite);
CREATE INDEX IF NOT EXISTS idx_bookmarks_deleted_at ON calendarnotes.bookmarks(deleted_at) WHERE deleted_at IS NULL;

-- Collections indexes
CREATE INDEX IF NOT EXISTS idx_collections_user_id ON calendarnotes.collections(user_id);
CREATE INDEX IF NOT EXISTS idx_collections_deleted_at ON calendarnotes.collections(deleted_at) WHERE deleted_at IS NULL;

-- Sync log indexes
CREATE INDEX IF NOT EXISTS idx_sync_log_user_id ON calendarnotes.sync_log(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_log_entity ON calendarnotes.sync_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_sync_log_synced_at ON calendarnotes.sync_log(synced_at);

-- ============================================
-- TRIGGERS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION calendarnotes.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to all tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON calendarnotes.users
    FOR EACH ROW EXECUTE FUNCTION calendarnotes.update_updated_at_column();

CREATE TRIGGER update_calendar_events_updated_at BEFORE UPDATE ON calendarnotes.calendar_events
    FOR EACH ROW EXECUTE FUNCTION calendarnotes.update_updated_at_column();

CREATE TRIGGER update_notes_updated_at BEFORE UPDATE ON calendarnotes.notes
    FOR EACH ROW EXECUTE FUNCTION calendarnotes.update_updated_at_column();

CREATE TRIGGER update_todo_items_updated_at BEFORE UPDATE ON calendarnotes.todo_items
    FOR EACH ROW EXECUTE FUNCTION calendarnotes.update_updated_at_column();

CREATE TRIGGER update_bookmarks_updated_at BEFORE UPDATE ON calendarnotes.bookmarks
    FOR EACH ROW EXECUTE FUNCTION calendarnotes.update_updated_at_column();

CREATE TRIGGER update_collections_updated_at BEFORE UPDATE ON calendarnotes.collections
    FOR EACH ROW EXECUTE FUNCTION calendarnotes.update_updated_at_column();

