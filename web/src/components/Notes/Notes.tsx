import { useMemo, useState } from 'react'
import { useNotes } from '../../hooks/useNotes'
import { useDebouncedValue } from '../../hooks/useDebouncedValue'
import { NotesListView } from './NotesListView'
import { NoteEditor } from './NoteEditor'
import type { Note } from '../../types'

export function Notes() {
  const [search, setSearch] = useState('')
  const debouncedSearch = useDebouncedValue(search, 300)
  const [selectedTag, setSelectedTag] = useState<string | null>(null)
  const [editorOpen, setEditorOpen] = useState(false)
  const [editingNote, setEditingNote] = useState<Note | null>(null)

  const query = useMemo(
    () => ({
      search: debouncedSearch || undefined,
      tags: selectedTag ? [selectedTag] : undefined,
    }),
    [debouncedSearch, selectedTag],
  )

  const { notes, allTags, isLoading, error, createNote, updateNote } = useNotes(query)

  function handleOpenNote(note?: Note) {
    setEditingNote(note ?? null)
    setEditorOpen(true)
  }

  async function handleSave(payload: {
    id?: string
    title: string
    content: string
    tags: string[]
    linkedDate?: string
  }) {
    if (payload.id) {
      await updateNote({ id: payload.id, payload })
    } else {
      await createNote({
        title: payload.title,
        content: payload.content,
        tags: payload.tags,
        linkedDate: payload.linkedDate,
      })
    }
  }

  function exportJson() {
    const blob = new Blob([JSON.stringify(notes, null, 2)], {
      type: 'application/json',
    })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'calendarnotes-notes.json'
    a.click()
    URL.revokeObjectURL(url)
  }

  function exportMarkdown() {
    const md = notes
      .map((note) => {
        const tags =
          note.tags && note.tags.length > 0
            ? `\n\nTags: ${note.tags.map((t) => `#${t}`).join(' ')}`
            : ''
        return `# ${note.title || 'Untitled note'}\n\n${
          note.content
        }${tags}\n\n---\n`
      })
      .join('\n')

    const blob = new Blob([md], { type: 'text/markdown' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'calendarnotes-notes.md'
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <div className="flex h-full flex-col gap-3">
      <div className="flex items-baseline justify-between gap-2">
        <h1 className="text-xl font-semibold tracking-tight">Notes</h1>
        {isLoading && (
          <span className="text-[0.65rem] text-slate-500">Loading notes…</span>
        )}
        {error && (
          <span className="text-[0.65rem] text-red-400">
            Unable to load notes. Please try again.
          </span>
        )}
      </div>

      <NotesListView
        notes={notes}
        search={search}
        onSearchChange={setSearch}
        selectedTag={selectedTag}
        onTagSelect={setSelectedTag}
        tags={allTags}
        onOpenNote={handleOpenNote}
        onExportJson={exportJson}
        onExportMarkdown={exportMarkdown}
      />

      <NoteEditor
        open={editorOpen}
        note={editingNote}
        onClose={() => setEditorOpen(false)}
        onSave={handleSave}
      />
    </div>
  )
}


