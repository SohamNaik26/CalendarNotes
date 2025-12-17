import { formatDistanceToNow } from 'date-fns'
import type { Note } from '../../types'

type Props = {
  notes: Note[]
  search: string
  onSearchChange: (value: string) => void
  selectedTag: string | null
  onTagSelect: (tag: string | null) => void
  tags: string[]
  onOpenNote: (note?: Note) => void
  onExportJson: () => void
  onExportMarkdown: () => void
}

const COLORS = ['border-sky-500', 'border-emerald-500', 'border-purple-500']

export function NotesListView({
  notes,
  search,
  onSearchChange,
  selectedTag,
  onTagSelect,
  tags,
  onOpenNote,
  onExportJson,
  onExportMarkdown,
}: Props) {
  return (
    <div className="flex h-full flex-col gap-3">
      <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
        <div className="relative w-full md:max-w-xs">
          <input
            type="search"
            placeholder="Search notes…"
            className="w-full rounded-2xl border border-slate-800 bg-slate-900 px-3 py-1.5 pr-9 text-xs text-slate-50 outline-none focus-visible:focus-ring"
            value={search}
            onChange={(e) => onSearchChange(e.target.value)}
          />
          <span className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-[0.65rem] text-slate-500">
            ⌘K
          </span>
        </div>

        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => onOpenNote(undefined)}
            className="rounded-2xl bg-gradient-to-r from-purple-500 to-pink-500 px-3 py-1.5 text-xs font-medium text-slate-50 shadow-md hover:shadow-lg hover:scale-[1.02] focus-visible:focus-ring"
          >
            New note
          </button>
          <button
            type="button"
            onClick={onExportJson}
            className="rounded-xl border border-slate-700 px-2 py-1 text-[0.65rem] text-slate-200 hover:bg-slate-800 focus-visible:focus-ring"
          >
            Export JSON
          </button>
          <button
            type="button"
            onClick={onExportMarkdown}
            className="rounded-xl border border-slate-700 px-2 py-1 text-[0.65rem] text-slate-200 hover:bg-slate-800 focus-visible:focus-ring"
          >
            Export MD
          </button>
        </div>
      </div>

      {tags.length > 0 && (
        <div className="flex flex-wrap gap-1 text-[0.65rem]">
          <button
            type="button"
            onClick={() => onTagSelect(null)}
            className={[
              'rounded-full border px-2 py-0.5',
              selectedTag === null
                ? 'border-purple-500 bg-purple-500/10 text-purple-200'
                : 'border-slate-700 text-slate-300 hover:bg-slate-800',
            ].join(' ')}
          >
            All
          </button>
          {tags.map((tag) => (
            <button
              key={tag}
              type="button"
              onClick={() => onTagSelect(tag)}
              className={[
                'rounded-full border px-2 py-0.5',
                selectedTag === tag
                  ? 'border-purple-500 bg-purple-500/10 text-purple-200'
                  : 'border-slate-700 text-slate-300 hover:bg-slate-800',
              ].join(' ')}
            >
              #{tag}
            </button>
          ))}
        </div>
      )}

      <div className="flex-1 overflow-y-auto rounded-2xl border border-slate-800 bg-slate-950/60 p-2">
        {notes.length === 0 ? (
          <div className="flex h-full flex-col items-center justify-center text-center text-xs text-slate-500">
            <div className="mb-3 h-14 w-14 rounded-3xl bg-gradient-to-br from-purple-500/20 via-sky-500/10 to-emerald-500/20" />
            <p className="font-medium text-slate-200 mb-1">No notes yet</p>
            <p className="max-w-xs">
              Start capturing ideas, meeting notes, and daily reflections. Your future
              self will thank you.
            </p>
          </div>
        ) : (
          <ul className="grid gap-2 md:grid-cols-2 xl:grid-cols-3">
            {notes.map((note, index) => {
              const colorClass = COLORS[index % COLORS.length]
              const preview =
                note.content.length > 140
                  ? `${note.content.slice(0, 140)}…`
                  : note.content

              return (
                <li key={note.id}>
                  <button
                    type="button"
                    onClick={() => onOpenNote(note)}
                    className={[
                      'group flex h-full w-full flex-col items-start rounded-2xl border-l-4 border-slate-700 bg-slate-900/80 p-3 text-left text-xs text-slate-200 shadow-sm transition',
                      colorClass,
                      'hover:shadow-lg hover:scale-[1.01] focus-visible:focus-ring',
                    ].join(' ')}
                  >
                    <p className="mb-1 line-clamp-1 text-xs font-semibold text-slate-50">
                      {note.title || 'Untitled note'}
                    </p>
                    <p className="mb-2 line-clamp-3 text-[0.7rem] text-slate-300">
                      {preview || 'No content yet'}
                    </p>
                    <div className="mt-auto flex w-full items-center justify-between gap-2">
                      <div className="flex flex-wrap gap-1">
                        {note.tags?.slice(0, 3).map((tag) => (
                          <span
                            key={tag}
                            className="rounded-full bg-slate-800 px-2 py-0.5 text-[0.6rem] text-slate-300"
                          >
                            #{tag}
                          </span>
                        ))}
                        {note.tags && note.tags.length > 3 && (
                          <span className="text-[0.6rem] text-slate-500">
                            +{note.tags.length - 3}
                          </span>
                        )}
                      </div>
                      <span className="text-[0.6rem] text-slate-500">
                        {formatDistanceToNow(new Date(note.updatedAt), {
                          addSuffix: true,
                        })}
                      </span>
                    </div>
                  </button>
                </li>
              )
            })}
          </ul>
        )}
      </div>
    </div>
  )
}


