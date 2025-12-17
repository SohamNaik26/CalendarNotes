import { FormEvent, useEffect, useState } from 'react'
import type { Task } from '../../types'

type Props = {
  open: boolean
  task: Task | null
  categories: string[]
  onClose: () => void
  onSave: (payload: {
    id?: string
    title: string
    description?: string
    dueDate?: string
    priority?: 'high' | 'medium' | 'low'
    category?: string
    recurrence?: 'none' | 'daily' | 'weekly' | 'monthly'
    linkedEventId?: string
  }) => Promise<void>
}

export function TaskEditor({ open, task, categories, onClose, onSave }: Props) {
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [dueDate, setDueDate] = useState<string | undefined>(undefined)
  const [priority, setPriority] =
    useState<'high' | 'medium' | 'low'>('medium')
  const [category, setCategory] = useState<string>('')
  const [newCategory, setNewCategory] = useState('')
  const [recurrence, setRecurrence] =
    useState<'none' | 'daily' | 'weekly' | 'monthly'>('none')
  const [linkedEventId, setLinkedEventId] = useState<string | undefined>()
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setTitle(task?.title ?? '')
    setDescription(task?.description ?? '')
    setDueDate(task?.dueDate)
    setPriority(task?.priority ?? 'medium')
    setCategory(task?.category ?? '')
    setNewCategory('')
    setRecurrence(task?.recurrence ?? 'none')
    setLinkedEventId(task?.linkedEventId)
    setSaving(false)
    setError(null)
  }, [open, task])

  if (!open) return null

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    if (!title.trim()) {
      setError('Title is required.')
      return
    }
    const chosenCategory = newCategory.trim() || category || undefined

    setSaving(true)
    setError(null)
    try {
      await onSave({
        id: task?.id,
        title: title.trim(),
        description: description.trim() || undefined,
        dueDate: dueDate || undefined,
        priority,
        category: chosenCategory,
        recurrence,
        linkedEventId: linkedEventId || undefined,
      })
      onClose()
    } catch {
      setError('Unable to save task. Please try again.')
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
      <div className="w-full max-w-lg rounded-2xl border border-slate-800 bg-slate-950/95 p-4 shadow-2xl">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-sm font-semibold text-slate-50">
            {task ? 'Edit task' : 'New task'}
          </h2>
          <button
            type="button"
            onClick={onClose}
            className="h-7 w-7 rounded-full border border-slate-700 text-slate-300 hover:bg-slate-800 focus-visible:focus-ring text-xs"
            aria-label="Close task editor"
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
            <label htmlFor="task-title" className="text-slate-200">
              Title
            </label>
            <input
              id="task-title"
              type="text"
              className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-1.5 text-xs outline-none focus-visible:focus-ring"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              required
            />
          </div>

          <div className="space-y-1">
            <label htmlFor="task-description" className="text-slate-200">
              Description
            </label>
            <textarea
              id="task-description"
              className="h-20 w-full resize-none rounded-lg border border-slate-700 bg-slate-950 px-3 py-1.5 text-xs outline-none focus-visible:focus-ring"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1">
              <label htmlFor="task-due" className="text-slate-200">
                Due date
              </label>
              <input
                id="task-due"
                type="date"
                className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-1.5 text-[0.7rem] outline-none focus-visible:focus-ring"
                value={dueDate ?? ''}
                onChange={(e) => setDueDate(e.target.value || undefined)}
              />
            </div>

            <div className="space-y-1">
              <label htmlFor="task-priority" className="text-slate-200">
                Priority
              </label>
              <select
                id="task-priority"
                className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-1.5 text-[0.7rem] outline-none focus-visible:focus-ring"
                value={priority}
                onChange={(e) =>
                  setPriority(e.target.value as 'high' | 'medium' | 'low')
                }
              >
                <option value="high">High</option>
                <option value="medium">Medium</option>
                <option value="low">Low</option>
              </select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1">
              <label htmlFor="task-category" className="text-slate-200">
                Category
              </label>
              <select
                id="task-category"
                className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-1.5 text-[0.7rem] outline-none focus-visible:focus-ring"
                value={category}
                onChange={(e) => setCategory(e.target.value)}
              >
                <option value="">None</option>
                {categories.map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>
              <input
                type="text"
                placeholder="Or create new…"
                className="mt-1 w-full rounded-lg border border-dashed border-slate-700 bg-slate-950 px-3 py-1.5 text-[0.7rem] outline-none focus-visible:focus-ring"
                value={newCategory}
                onChange={(e) => setNewCategory(e.target.value)}
              />
            </div>

            <div className="space-y-1">
              <label htmlFor="task-recurrence" className="text-slate-200">
                Recurring
              </label>
              <select
                id="task-recurrence"
                className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-1.5 text-[0.7rem] outline-none focus-visible:focus-ring"
                value={recurrence}
                onChange={(e) =>
                  setRecurrence(
                    e.target.value as 'none' | 'daily' | 'weekly' | 'monthly',
                  )
                }
              >
                <option value="none">Does not repeat</option>
                <option value="daily">Daily</option>
                <option value="weekly">Weekly</option>
                <option value="monthly">Monthly</option>
              </select>

              <label htmlFor="task-linked-event" className="mt-2 block text-slate-200">
                Link to calendar event
              </label>
              <input
                id="task-linked-event"
                type="text"
                placeholder="Event ID (optional)"
                className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-1.5 text-[0.7rem] outline-none focus-visible:focus-ring"
                value={linkedEventId ?? ''}
                onChange={(e) => setLinkedEventId(e.target.value || undefined)}
              />
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
              {saving ? 'Saving…' : 'Save task'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}


