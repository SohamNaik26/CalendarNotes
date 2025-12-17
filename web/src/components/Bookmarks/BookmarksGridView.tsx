import { useMemo, useState } from 'react'
import type { Bookmark } from '../../types'
import type { Collection } from '../../services/collections'

type Props = {
  bookmarks: Bookmark[]
  tags: string[]
  collections: Collection[]
  search: string
  selectedTag: string | null
  selectedCollectionId: string | null
  onSearchChange: (value: string) => void
  onTagSelect: (tag: string | null) => void
  onCollectionSelect: (id: string | null) => void
  onOpenBookmark: (bookmark?: Bookmark) => void
}

type ViewMode = 'grid' | 'list'

const GRADIENTS = [
  'from-purple-500/80 to-pink-500/80',
  'from-sky-500/80 to-cyan-400/80',
  'from-emerald-500/80 to-teal-400/80',
  'from-orange-500/80 to-red-500/80',
]

export function BookmarksGridView({
  bookmarks,
  tags,
  collections,
  search,
  selectedTag,
  selectedCollectionId,
  onSearchChange,
  onTagSelect,
  onCollectionSelect,
  onOpenBookmark,
}: Props) {
  const [view, setView] = useState<ViewMode>('grid')

  const collectionOptions = useMemo(
    () =>
      collections.map((c) => ({
        id: c.id,
        name: c.name,
      })),
    [collections],
  )

  const filtered = bookmarks.filter((b) => {
    if (selectedTag && !(b.tags ?? []).includes(selectedTag)) return false
    if (selectedCollectionId && b.collectionId !== selectedCollectionId) return false
    if (search) {
      const haystack = `${b.title} ${b.url} ${b.description ?? ''}`.toLowerCase()
      if (!haystack.includes(search.toLowerCase())) return false
    }
    return true
  })

  const GridTagPills = (
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
        All tags
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
  )

  return (
    <div className="flex h-full flex-col gap-3">
      <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
        <div className="flex flex-1 items-center gap-2">
          <div className="relative w-full max-w-xs">
            <input
              type="search"
              placeholder="Search bookmarks…"
              className="w-full rounded-2xl border border-slate-800 bg-slate-900 px-3 py-1.5 text-xs text-slate-50 outline-none focus-visible:focus-ring"
              value={search}
              onChange={(e) => onSearchChange(e.target.value)}
            />
          </div>

          <select
            className="rounded-2xl border border-slate-700 bg-slate-900 px-3 py-1.5 text-[0.7rem] text-slate-50 outline-none focus-visible:focus-ring"
            value={selectedCollectionId ?? ''}
            onChange={(e) =>
              onCollectionSelect(e.target.value ? e.target.value : null)
            }
          >
            <option value="">All collections</option>
            {collectionOptions.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </div>

        <div className="flex items-center gap-2 text-[0.7rem]">
          <div className="inline-flex rounded-2xl border border-slate-700 bg-slate-900 p-0.5">
            <button
              type="button"
              onClick={() => setView('grid')}
              className={[
                'rounded-2xl px-2 py-0.5',
                view === 'grid'
                  ? 'bg-gradient-to-r from-purple-500 to-pink-500 text-slate-50 shadow'
                  : 'text-slate-300 hover:bg-slate-800',
              ].join(' ')}
            >
              Grid
            </button>
            <button
              type="button"
              onClick={() => setView('list')}
              className={[
                'rounded-2xl px-2 py-0.5',
                view === 'list'
                  ? 'bg-gradient-to-r from-purple-500 to-pink-500 text-slate-50 shadow'
                  : 'text-slate-300 hover:bg-slate-800',
              ].join(' ')}
            >
              List
            </button>
          </div>

          <button
            type="button"
            onClick={() => onOpenBookmark(undefined)}
            className="rounded-2xl bg-gradient-to-r from-purple-500 to-pink-500 px-3 py-1.5 text-xs font-medium text-slate-50 shadow-md hover:shadow-lg hover:scale-[1.02] focus-visible:focus-ring"
          >
            New bookmark
          </button>
        </div>
      </div>

      {tags.length > 0 && GridTagPills}

      <div className="flex-1 overflow-y-auto rounded-2xl border border-slate-800 bg-slate-950/60 p-2">
        {filtered.length === 0 ? (
          <div className="flex h-full flex-col items-center justify-center text-center text-xs text-slate-500">
            <div className="mb-3 h-14 w-14 rounded-3xl bg-gradient-to-br from-purple-500/20 via-sky-500/10 to-emerald-500/20" />
            <p className="mb-1 font-medium text-slate-200">No bookmarks yet</p>
            <p className="max-w-xs">
              Save your favourite tools, docs, and inspirations here for quick access.
            </p>
          </div>
        ) : view === 'grid' ? (
          <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {filtered.map((bookmark, index) => (
              <li key={bookmark.id}>
                <button
                  type="button"
                  onClick={() => onOpenBookmark(bookmark)}
                  className={[
                    'flex h-full w-full flex-col items-start rounded-2xl bg-gradient-to-br p-3 text-left text-xs text-slate-50 shadow-md transition',
                    'hover:shadow-xl hover:scale-[1.02] focus-visible:focus-ring',
                    bookmark.color ?? GRADIENTS[index % GRADIENTS.length],
                  ].join(' ')}
                >
                  <div className="mb-2 flex items-center gap-2">
                    <div className="flex h-8 w-8 items-center justify-center rounded-full bg-slate-950/20 text-base">
                      {bookmark.iconEmoji ?? '🔖'}
                    </div>
                    <div>
                      <p className="text-sm font-bold leading-tight">
                        {bookmark.title}
                      </p>
                      <p className="text-[0.65rem] text-slate-100/90 line-clamp-1">
                        {bookmark.url}
                      </p>
                    </div>
                  </div>
                  {bookmark.description && (
                    <p className="mb-2 line-clamp-3 text-[0.7rem] text-slate-100/90">
                      {bookmark.description}
                    </p>
                  )}
                  <div className="mt-auto flex flex-wrap gap-1 text-[0.6rem]">
                    {bookmark.tags?.slice(0, 3).map((tag) => (
                      <span
                        key={tag}
                        className="rounded-full bg-slate-950/20 px-2 py-0.5"
                      >
                        #{tag}
                      </span>
                    ))}
                    {bookmark.tags && bookmark.tags.length > 3 && (
                      <span>+{bookmark.tags.length - 3}</span>
                    )}
                  </div>
                </button>
              </li>
            ))}
          </ul>
        ) : (
          <ul className="space-y-2">
            {filtered.map((bookmark, index) => (
              <li key={bookmark.id}>
                <button
                  type="button"
                  onClick={() => onOpenBookmark(bookmark)}
                  className={[
                    'flex w-full items-center justify-between rounded-2xl border border-slate-800 bg-slate-900/80 p-3 text-left text-xs text-slate-200 shadow-sm transition',
                    'hover:shadow-lg hover:scale-[1.01] focus-visible:focus-ring',
                  ].join(' ')}
                >
                  <div className="flex items-center gap-3">
                    <div
                      className={[
                        'flex h-8 w-8 items-center justify-center rounded-full bg-gradient-to-br text-base text-slate-50',
                        bookmark.color ?? GRADIENTS[index % GRADIENTS.length],
                      ].join(' ')}
                    >
                      {bookmark.iconEmoji ?? '🔖'}
                    </div>
                    <div>
                      <p className="text-sm font-semibold leading-tight text-slate-50">
                        {bookmark.title}
                      </p>
                      <p className="text-[0.65rem] text-slate-400 line-clamp-1">
                        {bookmark.url}
                      </p>
                    </div>
                  </div>
                  {bookmark.tags && bookmark.tags.length > 0 && (
                    <div className="ml-3 flex flex-wrap justify-end gap-1 text-[0.6rem]">
                      {bookmark.tags.slice(0, 2).map((tag) => (
                        <span
                          key={tag}
                          className="rounded-full bg-slate-800 px-2 py-0.5 text-slate-200"
                        >
                          #{tag}
                        </span>
                      ))}
                      {bookmark.tags.length > 2 && (
                        <span className="text-slate-500">
                          +{bookmark.tags.length - 2}
                        </span>
                      )}
                    </div>
                  )}
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  )
}


