import { FormEvent, useEffect, useMemo, useState } from 'react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import rehypeHighlight from 'rehype-highlight'
import type { Note } from '../../types'

type Props = {
  open: boolean
  note: Note | null
  defaultLinkedDate?: string
  onClose: () => void
  onSave: (payload: {
    id?: string
    title: string
    content: string
    tags: string[]
    linkedDate?: string
  }) => Promise<void>
}

export function NoteEditor({ open, note, defaultLinkedDate, onClose, onSave }: Props) {
  const [title, setTitle] = useState('')
  const [content, setContent] = useState('')
  const [tags, setTags] = useState<string[]>([])
  const [tagInput, setTagInput] = useState('')
  const [linkedDate, setLinkedDate] = useState<string | undefined>(defaultLinkedDate)
  const [mode, setMode] = useState<'edit' | 'preview'>('edit')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [autoSaveState, setAutoSaveState] = useState<'idle' | 'saving' | 'saved'>(
    'idle',
  )

  useEffect(() => {
    if (!open) return
    setTitle(note?.title ?? '')
    setContent(note?.content ?? '')
    setTags(note?.tags ?? [])
    setLinkedDate(note?.linkedDate ?? defaultLinkedDate)
    setTagInput('')
    setMode('edit')
    setSaving(false)
    setError(null)
    setAutoSaveState('idle')
  }, [open, note, defaultLinkedDate])

  useEffect(() => {
    if (!open) return
    if (!content && !title) return

    setAutoSaveState('saving')
    const handle = setTimeout(() => {
      setAutoSaveState('saved')
    }, 800)
    return () => clearTimeout(handle)
  }, [content, title, open])

  const tagSuggestions = useMemo(() => {
    const pieces = content
      .split(/\s+/)
      .filter((p) => p.startsWith('#') && p.length > 1)
      .map((p) => p.replace(/^#/, '').replace(/[^\w-]/g, ''))
    return Array.from(new Set(pieces)).filter((t) => t && !tags.includes(t))
  }, [content, tags])

  if (!open) return null

  function handleTagSubmit(e: FormEvent) {
    e.preventDefault()
    const trimmed = tagInput.trim().replace(/^#/, '')
    if (!trimmed) return
    if (!tags.includes(trimmed)) {
      setTags([...tags, trimmed])
    }
    setTagInput('')
  }

  async function handleSave(e: FormEvent) {
    e.preventDefault()
    if (!title.trim() && !content.trim()) {
      setError('Note cannot be empty.')
      return
    }
    setSaving(true)
    setError(null)
    try {
      await onSave({
        id: note?.id,
        title: title.trim() || 'Untitled note',
        content,
        tags,
        linkedDate,
      })
      onClose()
    } catch {
      setError('Unable to save note. Please try again.')
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
      <div className="flex h-full w-full max-w-5xl flex-col overflow-hidden rounded-2xl border border-slate-800 bg-slate-950/95 shadow-2xl">
        <header className="flex items-center justify-between border-b border-slate-800 px-4 py-2">
          <div className="flex items-center gap-2 text-xs text-slate-300">
            <button
              type="button"
              onClick={() => setMode('edit')}
              className={[
                'rounded-xl px-2 py-1',
                mode === 'edit'
                  ? 'bg-slate-800 text-slate-50'
                  : 'hover:bg-slate-900',
              ].join(' ')}
            >
              Edit
            </button>
            <button
              type="button"
              onClick={() => setMode('preview')}
              className={[
                'rounded-xl px-2 py-1',
                mode === 'preview'
                  ? 'bg-slate-800 text-slate-50'
                  : 'hover:bg-slate-900',
              ].join(' ')}
            >
              Preview
            </button>
            <span className="ml-2 text-[0.65rem] text-slate-500">
              {autoSaveState === 'saving' && 'Auto-saving…'}
              {autoSaveState === 'saved' && 'All changes saved'}
            </span>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="h-7 w-7 rounded-full border border-slate-700 text-slate-300 hover:bg-slate-800 focus-visible:focus-ring text-xs"
            aria-label="Close note editor"
          >
            ✕
          </button>
        </header>

        <form
          onSubmit={handleSave}
          className="flex flex-1 flex-col md:flex-row"
          noValidate
        >
          <div className="flex-1 border-b border-slate-800 p-3 text-xs text-slate-50 md:border-b-0 md:border-r md:p-4">
            <div className="space-y-2">
              <input
                type="text"
                placeholder="Note title"
                className="w-full border-b border-slate-700 bg-transparent pb-1 text-sm font-semibold outline-none placeholder:text-slate-500"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
              />

              <textarea
                placeholder="Write in Markdown…"
                className="mt-2 h-56 w-full resize-none rounded-xl border border-slate-800 bg-slate-950/80 p-3 text-xs text-slate-50 outline-none focus-visible:focus-ring md:h-[calc(100vh-13rem)]"
                value={content}
                onChange={(e) => setContent(e.target.value)}
              />

              <div className="grid gap-2 text-[0.7rem] md:grid-cols-[1.2fr_0.8fr]">
                <div className="space-y-1">
                  <p className="text-slate-300">Tags</p>
                  <form
                    className="flex items-center gap-2"
                    onSubmit={handleTagSubmit}
                  >
                    <input
                      type="text"
                      placeholder="#tag"
                      className="flex-1 rounded-lg border border-slate-700 bg-slate-950 px-2 py-1 outline-none focus-visible:focus-ring"
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

                <div className="space-y-1">
                  <p className="text-slate-300">Link to calendar</p>
                  <input
                    type="date"
                    className="w-full rounded-lg border border-slate-700 bg-slate-950 px-2 py-1 text-[0.7rem] text-slate-50 outline-none focus-visible:focus-ring"
                    value={linkedDate ?? ''}
                    onChange={(e) =>
                      setLinkedDate(e.target.value || undefined)
                    }
                  />
                  <p className="text-[0.6rem] text-slate-500">
                    Link this note to a specific day in your calendar.
                  </p>
                </div>
              </div>
            </div>
          </div>

          <div className="flex w-full flex-1 flex-col border-t border-slate-800 bg-slate-950/90 text-xs text-slate-50 md:max-w-md md:border-t-0">
            <div className="flex-1 overflow-y-auto p-3 md:p-4">
              {mode === 'preview' ? (
                <article className="prose prose-invert max-w-none prose-pre:bg-slate-900 prose-pre:border prose-pre:border-slate-800 prose-code:text-[0.75rem]">
                  <ReactMarkdown
                    remarkPlugins={[remarkGfm]}
                    rehypePlugins={[rehypeHighlight]}
                  >
                    {content || '_Nothing here yet…_'}
                  </ReactMarkdown>
                </article>
              ) : (
                <p className="text-[0.7rem] text-slate-500">
                  Switch to preview to see rendered Markdown.
                </p>
              )}
            </div>

            <footer className="flex items-center justify-between gap-2 border-t border-slate-800 px-3 py-2 md:px-4">
              {error && (
                <p className="text-[0.65rem] text-red-400">{error}</p>
              )}
              <div className="ml-auto flex items-center gap-2">
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
                  {saving ? 'Saving…' : 'Save note'}
                </button>
              </div>
            </footer>
          </div>
        </form>
      </div>
    </div>
  )
}


