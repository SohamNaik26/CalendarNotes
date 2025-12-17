import { FormEvent, useEffect, useMemo, useState } from 'react'
import type { Bookmark } from '../../types'
import type { Collection } from '../../services/collections'

type Props = {
  open: boolean
  bookmark: Bookmark | null
  collections: Collection[]
  allTags: string[]
  onClose: () => void
  onSave: (payload: {
    id?: string
    url: string
    title?: string
    description?: string
    tags?: string[]
    collectionId?: string
    color?: string
    iconEmoji?: string
  }) => Promise<void>
}

const EMOJIS = ['🌐', '💻', '📚', '🎨', '🧠', '🧪', '🧰', '📌']

export function BookmarkEditor({
  open,
  bookmark,
  collections,
  allTags,
  onClose,
  onSave,
}: Props) {
  const [url, setUrl] = useState('')
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [collectionId, setCollectionId] = useState<string | undefined>()
  const [tags, setTags] = useState<string[]>([])
  const [tagInput, setTagInput] = useState('')
  const [color, setColor] = useState('#a855f7')
  const [iconEmoji, setIconEmoji] = useState('🔖')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setUrl(bookmark?.url ?? '')
    setTitle(bookmark?.title ?? '')
    setDescription(bookmark?.description ?? '')
    setCollectionId(bookmark?.collectionId)
    setTags(bookmark?.tags ?? [])
    setTagInput('')
    setColor(bookmark?.color ?? '#a855f7')
    setIconEmoji(bookmark?.iconEmoji ?? '🔖')
    setSaving(false)
    setError(null)
  }, [open, bookmark])

  const tagSuggestions = useMemo(
    () => allTags.filter((t) => !tags.includes(t)),
    [allTags, tags],
  )

  if (!open) return null

  function isValidUrl(value: string) {
    try {
      // eslint-disable-next-line no-new
      new URL(value)
      return true
    } catch {
      return false
    }
  }

  function handleTagSubmit(e: FormEvent) {
    e.preventDefault()
    const trimmed = tagInput.trim().replace(/^#/, '')
    if (!trimmed) return
    if (!tags.includes(trimmed)) {
      setTags([...tags, trimmed])
    }
    setTagInput('')
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    if (!url.trim() || !isValidUrl(url.trim())) {
      setError('Please enter a valid URL.')
      return
    }

    setSaving(true)
    setError(null)
    try {
      await onSave({
        id: bookmark?.id,
        url: url.trim(),
        title: title.trim() || undefined,
        description: description.trim() || undefined,
        tags,
        collectionId,
        color,
        iconEmoji,
      })
      onClose()
    } catch {
      setError('Unable to save bookmark. Please try again.')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div
      className="fixed inset-0 z-40 flex items-center justify-center bg-black/50 p-2 md:p-4"
      role="dialog"
      aria-modal="true"
    >
      <div className="w-full max-w-xl rounded-2xl border border-slate-800 bg-slate-950/95 p-4 shadow-2xl">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-sm font-semibold text-slate-50">
            {bookmark ? 'Edit bookmark' : 'New bookmark'}
          </h2>
          <button
            type="button"
            onClick={onClose}
            className="h-7 w-7 rounded-full border border-slate-700 text-slate-300 hover:bg-slate-800 focus-visible:focus-ring text-xs"
            aria-label="Close bookmark editor"
          >
            ✕
          </button>
        </div>

        <form
          className="space-y-3 text-xs text-slate-50"
          onSubmit={handleSubmit}
          noValidate
        >
          <div className="space-y-1">
            <label htmlFor="bookmark-url" className="text-slate-200">
              URL
            </label>
            <input
              id="bookmark-url"
              type="url"
              className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-1.5 text-xs outline-none focus-visible:focus-ring"
              placeholder="https://example.com"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              required
            />
          </div>

          <div className="space-y-1">
            <label htmlFor="bookmark-title" className="text-slate-200">
              Title
            </label>
            <input
              id="bookmark-title"
              type="text"
              className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-1.5 text-xs outline-none focus-visible:focus-ring"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
            />
          </div>

          <div className="space-y-1">
            <label htmlFor="bookmark-description" className="text-slate-200">
              Description
            </label>
            <textarea
              id="bookmark-description"
              className="h-20 w-full resize-none rounded-lg border border-slate-700 bg-slate-950 px-3 py-1.5 text-xs outline-none focus-visible:focus-ring"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
            />
          </div>

          <div className="grid grid-cols-[minmax(0,1.2fr)_minmax(0,0.8fr)] gap-3">
            <div className="space-y-1">
              <label htmlFor="bookmark-collection" className="text-slate-200">
                Collection
              </label>
              <select
                id="bookmark-collection"
                className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-1.5 text-[0.7rem] outline-none focus-visible:focus-ring"
                value={collectionId ?? ''}
                onChange={(e) =>
                  setCollectionId(e.target.value || undefined)
                }
              >
                <option value="">None</option>
                {collections.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>

              <div className="mt-2 space-y-1">
                <p className="text-slate-200">Tags</p>
                <form
                  className="flex items-center gap-2"
                  onSubmit={handleTagSubmit}
                >
                  <input
                    type="text"
                    placeholder="#tag"
                    className="flex-1 rounded-lg border border-slate-700 bg-slate-950 px-2 py-1 text-[0.7rem] outline-none focus-visible:focus-ring"
                    value={tagInput}
                    onChange={(e) => setTagInput(e.target.value)}
                  />
                  <button
                    type="submit"
                    className="rounded-lg border border-slate-700 px-2 py-1 text-[0.65rem] text-slate-200 hover:bg-slate-800 focus-visible:focus-ring"
                  >
                    Add
                  </button>
                </form>
                <div className="mt-1 flex flex-wrap gap-1">
                  {tags.map((tag) => (
                    <button
                      key={tag}
                      type="button"
                      onClick={() =>
                        setTags(tags.filter((existing) => existing !== tag))
                      }
                      className="rounded-full bg-slate-800 px-2 py-0.5 text-[0.65rem] text-slate-200 hover:bg-slate-700"
                    >
                      #{tag}
                    </button>
                  ))}
                </div>
                {tagSuggestions.length > 0 && (
                  <div className="mt-1 flex flex-wrap gap-1 text-[0.6rem] text-slate-400">
                    <span>Suggestions:</span>
                    {tagSuggestions.map((tag) => (
                      <button
                        key={tag}
                        type="button"
                        onClick={() => setTags([...tags, tag])}
                        className="rounded-full bg-slate-900 px-2 py-0.5 hover:bg-slate-800"
                      >
                        #{tag}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>

            <div className="space-y-1">
              <label htmlFor="bookmark-color" className="text-slate-200">
                Card color
              </label>
              <input
                id="bookmark-color"
                type="color"
                className="h-9 w-full rounded-lg border border-slate-700 bg-slate-950 p-1"
                value={color}
                onChange={(e) => setColor(e.target.value)}
              />

              <p className="mt-2 text-slate-200">Icon</p>
              <div className="flex flex-wrap gap-1">
                {EMOJIS.map((emoji) => (
                  <button
                    key={emoji}
                    type="button"
                    onClick={() => setIconEmoji(emoji)}
                    className={[
                      'flex h-7 w-7 items-center justify-center rounded-full border text-sm',
                      iconEmoji === emoji
                        ? 'border-purple-500 bg-purple-500/20'
                        : 'border-slate-700 bg-slate-900 hover:bg-slate-800',
                    ].join(' ')}
                  >
                    {emoji}
                  </button>
                ))}
              </div>
            </div>
          </div>

          {error && (
            <p className="text-[0.65rem] text-red-400">
              {error}
            </p>
          )}

          <div className="flex justify-end gap-2 pt-1">
            <button
              type="button"
              onClick={onClose}
              className="rounded-lg border border-slate-700 px-3 py-1.5 text-[0.7rem] text-slate-200 hover:bg-slate-800 focus-visible:focus-ring"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={saving}
              className="rounded-lg bg-gradient-to-r from-purple-500 to-pink-500 px-3 py-1.5 text-[0.7rem] font-medium text-slate-50 shadow-md hover:shadow-lg hover:scale-[1.02] focus-visible:focus-ring disabled:opacity-60"
            >
              {saving ? 'Saving…' : 'Save bookmark'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}


