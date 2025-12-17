import { FormEvent, useEffect, useState } from 'react'
import { format } from 'date-fns'
import type { CalendarEvent } from '../../types'
import type { EventPayload } from '../../services/events'
import type { Holiday } from '../../utils/holidays2025'

type Props = {
  open: boolean
  date: Date | null
  events: CalendarEvent[]
  holiday: Holiday | null
  loading?: boolean
  error?: unknown
  onClose: () => void
  onSave: (payload: EventPayload, existingId?: string) => Promise<void>
  onDelete: (id: string) => Promise<void>
}

const CATEGORY_OPTIONS: EventPayload['category'][] = [
  'work',
  'personal',
  'health',
  'holiday',
]

const RECURRENCE_OPTIONS: Exclude<EventPayload['recurrence'], undefined>[] = [
  'none',
  'daily',
  'weekly',
  'monthly',
]

export function EventModal({
  open,
  date,
  events,
  holiday,
  loading,
  error,
  onClose,
  onSave,
  onDelete,
}: Props) {
  const [editingId, setEditingId] = useState<string | undefined>()
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [start, setStart] = useState('')
  const [end, setEnd] = useState('')
  const [location, setLocation] = useState('')
  const [category, setCategory] = useState<EventPayload['category']>('work')
  const [color, setColor] = useState('#6366f1')
  const [allDay, setAllDay] = useState(false)
  const [recurrence, setRecurrence] =
    useState<EventPayload['recurrence']>('none')
  const [formError, setFormError] = useState<string | null>(null)

  useEffect(() => {
    if (!open || !date) return

    const base = date.toISOString().slice(0, 10)
    const defaultStart = `${base}T09:00`
    const defaultEnd = `${base}T10:00`

    setEditingId(undefined)
    setTitle('')
    setDescription('')
    setStart(defaultStart)
    setEnd(defaultEnd)
    setLocation('')
    setCategory('work')
    setColor('#6366f1')
    setAllDay(false)
    setRecurrence('none')
    setFormError(null)
  }, [open, date])

  useEffect(() => {
    if (!editingId) return
    const existing = events.find((e) => e.id === editingId)
    if (!existing) return

    setTitle(existing.title)
    setDescription(existing.notes ?? '')
    setStart(existing.start.slice(0, 16))
    setEnd(existing.end.slice(0, 16))
  }, [editingId, events])

  if (!open || !date) return null

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    setFormError(null)

    if (!title.trim()) {
      setFormError('Title is required.')
      return
    }
    if (!start || !end) {
      setFormError('Start and end date/time are required.')
      return
    }
    if (new Date(start) >= new Date(end)) {
      setFormError('End time must be after start time.')
      return
    }

    const payload: EventPayload = {
      title: title.trim(),
      description: description.trim() || undefined,
      start: new Date(start).toISOString(),
      end: new Date(end).toISOString(),
      location: location.trim() || undefined,
      category,
      color,
      allDay,
      recurrence,
      isIndianHoliday: holiday?.isIndian,
      isInternationalHoliday: holiday?.isInternational,
    }

    await onSave(payload, editingId)
    setEditingId(undefined)
  }

  function cardGradient(e: CalendarEvent) {
    if (e.isIndianHoliday) return 'from-orange-50 to-amber-50 text-amber-900'
    if (e.isInternationalHoliday) return 'from-pink-50 to-rose-50 text-rose-900'

    const cat = categoryFromEvent(e)
    if (cat === 'work') return 'from-blue-50 to-cyan-50 text-slate-900'
    if (cat === 'personal') return 'from-green-50 to-emerald-50 text-slate-900'
    if (cat === 'health') return 'from-red-50 to-pink-50 text-slate-900'
    return 'from-purple-50 to-pink-50 text-slate-900'
  }

  function categoryFromEvent(e: CalendarEvent): EventPayload['category'] {
    if (e.isIndianHoliday || e.isInternationalHoliday) return 'holiday'
    // backend events may not include category; default to work
    return 'work'
  }

  function iconFor(e: CalendarEvent) {
    const cat = categoryFromEvent(e)
    if (e.isIndianHoliday) return '🎉'
    if (e.isInternationalHoliday) return '🎉'
    if (cat === 'work') return '💼'
    if (cat === 'personal') return '👤'
    if (cat === 'health') return '🏥'
    return '🎉'
  }

  return (
    <div
      className="fixed inset-0 z-40 flex items-end justify-center bg-black/40 px-2 pb-4 pt-8 md:items-center md:p-4 animate-in fade-in"
      role="dialog"
      aria-modal="true"
    >
      <div
        className="w-full max-w-md md:max-w-2xl rounded-2xl border border-slate-800 bg-slate-950/95 shadow-2xl transform transition-transform duration-300 ease-out translate-y-0 md:translate-y-0 animate-in slide-in-from-bottom"
      >
        <div className="flex items-center justify-between border-b border-slate-800 px-4 py-3">
          <div>
            <p className="text-xs text-slate-400">Events on</p>
            <p className="text-sm font-semibold text-slate-50">
              {format(date, 'EEEE, MMM d, yyyy')}
            </p>
            {holiday && (
              <p className="mt-0.5 text-xs text-slate-300">
                {holiday.name}{' '}
                {holiday.isIndian && <span className="ml-1 rounded-full bg-orange-500/10 px-2 py-0.5 text-[0.65rem] text-orange-300">🇮🇳 Indian Holiday</span>}
                {holiday.isInternational && (
                  <span className="ml-1 rounded-full bg-pink-500/10 px-2 py-0.5 text-[0.65rem] text-pink-300">
                    🌍 International
                  </span>
                )}
              </p>
            )}
          </div>
          <button
            type="button"
            onClick={onClose}
            className="h-7 w-7 rounded-full border border-slate-700 text-slate-300 hover:bg-slate-800 focus-visible:focus-ring text-xs"
            aria-label="Close event modal"
          >
            ✕
          </button>
        </div>

        <div className="grid gap-4 p-4 md:grid-cols-[minmax(0,1.1fr)_minmax(0,1.2fr)]">
          <div className="space-y-2 max-h-72 overflow-y-auto">
            <div className="flex items-center justify-between">
              <p className="text-xs font-medium text-slate-300">Events</p>
            </div>

            {loading && (
              <p className="text-xs text-slate-400">Loading events…</p>
            )}

            {error && (
              <p className="text-xs text-red-400">
                Something went wrong while loading events.
              </p>
            )}

            {!loading && events.length === 0 && !holiday && (
              <p className="text-xs text-slate-500">
                No events yet. Add your first one on this day.
              </p>
            )}

            {events.map((e) => (
              <button
                key={e.id}
                type="button"
                onClick={() => setEditingId(e.id)}
                className={[
                  'w-full rounded-xl bg-gradient-to-r px-3 py-2 text-left shadow-md text-xs',
                  'hover:shadow-lg hover:scale-[1.01] transition-transform',
                  cardGradient(e),
                ].join(' ')}
              >
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-1.5">
                    <span className="text-sm">{iconFor(e)}</span>
                    <span className="font-medium truncate">{e.title}</span>
                  </div>
                  <span className="text-[0.6rem] opacity-70">
                    {format(new Date(e.start), 'p')} –{' '}
                    {format(new Date(e.end), 'p')}
                  </span>
                </div>
                {e.notes && (
                  <p className="mt-0.5 line-clamp-2 text-[0.65rem] opacity-80">
                    {e.notes}
                  </p>
                )}
                {(e as any).location && (
                  <p className="mt-0.5 text-[0.6rem] opacity-70">
                    {(e as any).location}
                  </p>
                )}
                {(e.isIndianHoliday || e.isInternationalHoliday) && (
                  <div className="mt-1 flex flex-wrap gap-1 text-[0.6rem]">
                    {e.isIndianHoliday && (
                      <span className="rounded-full bg-orange-500/10 px-2 py-0.5 text-orange-400">
                        🇮🇳 Indian Holiday
                      </span>
                    )}
                    {e.isInternationalHoliday && (
                      <span className="rounded-full bg-pink-500/10 px-2 py-0.5 text-pink-300">
                        🌍 International
                      </span>
                    )}
                  </div>
                )}
                <div className="mt-1 flex justify-end">
                  <button
                    type="button"
                    onClick={(ev) => {
                      ev.stopPropagation()
                      void onDelete(e.id)
                    }}
                    className="text-[0.6rem] text-red-500 hover:text-red-400 underline underline-offset-2"
                  >
                    Delete
                  </button>
                </div>
              </button>
            ))}
          </div>

          <div className="space-y-3 rounded-2xl border border-slate-800 bg-slate-950/60 p-3">
            <p className="text-xs font-medium text-slate-300">
              {editingId ? 'Edit event' : 'Add event'}
            </p>

            <form
              className="space-y-2 text-xs"
              onSubmit={handleSubmit}
              noValidate
            >
              <div className="space-y-1">
                <label className="text-slate-200" htmlFor="event-title">
                  Title
                </label>
                <input
                  id="event-title"
                  type="text"
                  className="w-full rounded-lg border border-slate-700 bg-slate-900 px-2 py-1.5 text-xs text-slate-50 outline-none focus-visible:focus-ring"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  required
                />
              </div>

              <div className="space-y-1">
                <label className="text-slate-200" htmlFor="event-description">
                  Description
                </label>
                <textarea
                  id="event-description"
                  className="w-full rounded-lg border border-slate-700 bg-slate-900 px-2 py-1.5 text-xs text-slate-50 outline-none focus-visible:focus-ring resize-none h-16"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                />
              </div>

              <div className="grid grid-cols-2 gap-2">
                <div className="space-y-1">
                  <label className="text-slate-200" htmlFor="event-start">
                    Start
                  </label>
                  <input
                    id="event-start"
                    type="datetime-local"
                    className="w-full rounded-lg border border-slate-700 bg-slate-900 px-2 py-1.5 text-xs text-slate-50 outline-none focus-visible:focus-ring"
                    value={start}
                    onChange={(e) => setStart(e.target.value)}
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-slate-200" htmlFor="event-end">
                    End
                  </label>
                  <input
                    id="event-end"
                    type="datetime-local"
                    className="w-full rounded-lg border border-slate-700 bg-slate-900 px-2 py-1.5 text-xs text-slate-50 outline-none focus-visible:focus-ring"
                    value={end}
                    onChange={(e) => setEnd(e.target.value)}
                  />
                </div>
              </div>

              <div className="space-y-1">
                <label className="text-slate-200" htmlFor="event-location">
                  Location
                </label>
                <input
                  id="event-location"
                  type="text"
                  className="w-full rounded-lg border border-slate-700 bg-slate-900 px-2 py-1.5 text-xs text-slate-50 outline-none focus-visible:focus-ring"
                  value={location}
                  onChange={(e) => setLocation(e.target.value)}
                />
              </div>

              <div className="grid grid-cols-2 gap-2">
                <div className="space-y-1">
                  <label className="text-slate-200" htmlFor="event-category">
                    Category
                  </label>
                  <select
                    id="event-category"
                    className="w-full rounded-lg border border-slate-700 bg-slate-900 px-2 py-1.5 text-xs text-slate-50 outline-none focus-visible:focus-ring"
                    value={category}
                    onChange={(e) =>
                      setCategory(e.target.value as EventPayload['category'])
                    }
                  >
                    {CATEGORY_OPTIONS.map((opt) => (
                      <option key={opt} value={opt}>
                        {opt[0].toUpperCase() + opt.slice(1)}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="space-y-1">
                  <label className="text-slate-200" htmlFor="event-color">
                    Color
                  </label>
                  <input
                    id="event-color"
                    type="color"
                    className="h-8 w-full rounded-lg border border-slate-700 bg-slate-900 p-1"
                    value={color}
                    onChange={(e) => setColor(e.target.value)}
                  />
                </div>
              </div>

              <div className="flex items-center gap-3">
                <label className="inline-flex items-center gap-1.5 text-xs text-slate-200">
                  <input
                    type="checkbox"
                    className="h-3.5 w-3.5 rounded border-slate-700 bg-slate-900 text-brand-500"
                    checked={allDay}
                    onChange={(e) => setAllDay(e.target.checked)}
                  />
                  All-day
                </label>

                <div className="flex-1">
                  <label className="mr-1 text-slate-200" htmlFor="event-recurrence">
                    Repeat
                  </label>
                  <select
                    id="event-recurrence"
                    className="rounded-lg border border-slate-700 bg-slate-900 px-2 py-1 text-[0.65rem] text-slate-50 outline-none focus-visible:focus-ring"
                    value={recurrence}
                    onChange={(e) =>
                      setRecurrence(e.target.value as EventPayload['recurrence'])
                    }
                  >
                    {RECURRENCE_OPTIONS.map((opt) => (
                      <option key={opt} value={opt}>
                        {opt === 'none' ? 'Does not repeat' : opt[0].toUpperCase() + opt.slice(1)}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {(formError || error) && (
                <p className="text-[0.65rem] text-red-400">
                  {formError ??
                    'There was a problem saving this event. Please try again.'}
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
                  className="rounded-lg bg-gradient-to-r from-purple-500 to-pink-500 px-3 py-1.5 text-[0.7rem] font-medium text-slate-50 shadow-md hover:shadow-lg hover:scale-105 focus-visible:focus-ring disabled:opacity-60"
                  disabled={Boolean(loading)}
                >
                  Save
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
  )
}


