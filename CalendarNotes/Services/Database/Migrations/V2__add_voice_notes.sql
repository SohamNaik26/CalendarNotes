-- Migration V2: Add Voice Notes Table
-- This migration adds support for voice notes functionality
-- Applied: Adds voice_notes table and related indexes

-- Voice notes table
CREATE TABLE IF NOT EXISTS calendarnotes.voice_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES calendarnotes.users(id) ON DELETE CASCADE,
    title VARCHAR(255),
    audio_file_url TEXT NOT NULL,
    duration_seconds INTEGER,
    transcription TEXT,
    language VARCHAR(10) DEFAULT 'en',
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    synced_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Indexes for voice notes
CREATE INDEX IF NOT EXISTS idx_voice_notes_user_id ON calendarnotes.voice_notes(user_id);
CREATE INDEX IF NOT EXISTS idx_voice_notes_created_at ON calendarnotes.voice_notes(created_at);
CREATE INDEX IF NOT EXISTS idx_voice_notes_fulltext ON calendarnotes.voice_notes USING GIN(to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(transcription, '')));
CREATE INDEX IF NOT EXISTS idx_voice_notes_deleted_at ON calendarnotes.voice_notes(deleted_at) WHERE deleted_at IS NULL;

-- Apply updated_at trigger to voice_notes table
CREATE TRIGGER update_voice_notes_updated_at BEFORE UPDATE ON calendarnotes.voice_notes
    FOR EACH ROW EXECUTE FUNCTION calendarnotes.update_updated_at_column();

