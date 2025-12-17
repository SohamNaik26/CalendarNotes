import { useMemo, useState } from 'react'
import { useBookmarks } from '../../hooks/useBookmarks'
import { useCollections } from '../../hooks/useCollections'
import { BookmarksGridView } from './BookmarksGridView'
import { BookmarkEditor } from './BookmarkEditor'
import type { Bookmark } from '../../types'

export function Bookmarks() {
  const [search, setSearch] = useState('')
  const [selectedTag, setSelectedTag] = useState<string | null>(null)
  const [selectedCollectionId, setSelectedCollectionId] = useState<string | null>(
    null,
  )
  const [editorOpen, setEditorOpen] = useState(false)
  const [editingBookmark, setEditingBookmark] = useState<Bookmark | null>(null)

  const query = useMemo(
    () => ({
      search: search || undefined,
      tags: selectedTag ? [selectedTag] : undefined,
      collectionId: selectedCollectionId ?? undefined,
    }),
    [search, selectedTag, selectedCollectionId],
  )

  const { bookmarks, tags, isLoading, error, createBookmark, updateBookmark } =
    useBookmarks(query)
  const { collections } = useCollections()

  function openEditor(bookmark?: Bookmark) {
    setEditingBookmark(bookmark ?? null)
    setEditorOpen(true)
  }

  async function handleSave(payload: {
    id?: string
    url: string
    title?: string
    description?: string
    tags?: string[]
    collectionId?: string
    color?: string
    iconEmoji?: string
  }) {
    if (payload.id) {
      await updateBookmark({ id: payload.id, payload })
    } else {
      await createBookmark(payload)
    }
  }

  return (
    <div className="flex h-full flex-col gap-3">
      <div className="flex items-baseline justify-between gap-2">
        <h1 className="text-xl font-semibold tracking-tight">Bookmarks</h1>
        {isLoading && (
          <span className="text-[0.65rem] text-slate-500">
            Loading bookmarks…
          </span>
        )}
        {error && (
          <span className="text-[0.65rem] text-red-400">
            Unable to load bookmarks. Please try again.
          </span>
        )}
      </div>

      <BookmarksGridView
        bookmarks={bookmarks}
        tags={tags}
        collections={collections}
        search={search}
        selectedTag={selectedTag}
        selectedCollectionId={selectedCollectionId}
        onSearchChange={setSearch}
        onTagSelect={setSelectedTag}
        onCollectionSelect={setSelectedCollectionId}
        onOpenBookmark={openEditor}
      />

      <BookmarkEditor
        open={editorOpen}
        bookmark={editingBookmark}
        collections={collections}
        allTags={tags}
        onClose={() => setEditorOpen(false)}
        onSave={handleSave}
      />
    </div>
  )
}


