import {
  addDays,
  addMonths,
  addWeeks,
  endOfMonth,
  format,
  startOfDay,
  startOfMonth,
  subDays,
  subMonths,
  subWeeks,
} from 'date-fns'
import { useAppStore } from '../../store/useAppStore'
import { MonthView } from './MonthView'
import { DayView } from './DayView'
import { WeekView } from './WeekView'
import { YearView } from './YearView'
import { useEvents } from '../../hooks/useEvents'
import { EventModal } from './EventModal'
import { getHolidayForDate } from '../../utils/holidays2025'
import type { EventPayload } from '../../services/events'

export type CalendarView = 'day' | 'week' | 'month' | 'year'

export type CalendarCategory = 'work' | 'personal' | 'health' | 'holiday'

export type CalendarEvent = {
  id: string
  title: string
  category: CalendarCategory
  start: string
  end: string
  isIndianHoliday?: boolean
  isInternationalHoliday?: boolean
}

// Simple in-memory sample events so the calendar feels alive.
export const sampleEvents: CalendarEvent[] = (() => {
  const today = startOfDay(new Date())
  const tomorrow = addDays(today, 1)

  return [
    {
      id: '1',
      title: 'Daily standup',
      category: 'work',
      start: addHoursSafe(today, 9).toISOString(),
      end: addHoursSafe(today, 9.5).toISOString(),
    },
    {
      id: '2',
      title: 'Deep work – planning',
      category: 'work',
      start: addHoursSafe(today, 11).toISOString(),
      end: addHoursSafe(today, 13).toISOString(),
    },
    {
      id: '3',
      title: 'Evening run',
      category: 'health',
      start: addHoursSafe(today, 18).toISOString(),
      end: addHoursSafe(today, 19).toISOString(),
    },
    {
      id: '4',
      title: 'Dinner with friends',
      category: 'personal',
      start: addHoursSafe(tomorrow, 20).toISOString(),
      end: addHoursSafe(tomorrow, 22).toISOString(),
    },
    {
      id: '5',
      title: 'Indian Holiday',
      category: 'holiday',
      start: today.toISOString(),
      end: addHoursSafe(today, 23.99).toISOString(),
      isIndianHoliday: true,
    },
    {
      id: '6',
      title: 'International Holiday',
      category: 'holiday',
      start: addDays(today, 2).toISOString(),
      end: addHoursSafe(addDays(today, 2), 23.99).toISOString(),
      isInternationalHoliday: true,
    },
  ]
})()

function addHoursSafe(date: Date, hours: number) {
  return new Date(date.getTime() + hours * 60 * 60 * 1000)
}

export function Calendar() {
  const { selectedDate, view, setSelectedDate, setView } = useAppStore()
  const currentDate = new Date(selectedDate)

  const range = getRangeForView(currentDate, view)
  const { events, isLoading, error, createEvent, updateEvent, deleteEvent } = useEvents({
    from: range.from.toISOString(),
    to: range.to.toISOString(),
  })

  const [modalOpen, setModalOpen] = useState(false)
  const [modalDate, setModalDate] = useState<Date | null>(null)

  function handlePrev() {
    if (view === 'day') setSelectedDate(formatDateISO(subDays(currentDate, 1)))
    else if (view === 'week') setSelectedDate(formatDateISO(subWeeks(currentDate, 1)))
    else if (view === 'month') setSelectedDate(formatDateISO(subMonths(currentDate, 1)))
    else setSelectedDate(formatDateISO(subMonths(currentDate, 12)))
  }

  function handleNext() {
    if (view === 'day') setSelectedDate(formatDateISO(addDays(currentDate, 1)))
    else if (view === 'week') setSelectedDate(formatDateISO(addWeeks(currentDate, 1)))
    else if (view === 'month') setSelectedDate(formatDateISO(addMonths(currentDate, 1)))
    else setSelectedDate(formatDateISO(addMonths(currentDate, 12)))
  }

  function handleToday() {
    setSelectedDate(formatDateISO(new Date()))
  }

  function openModalFor(date: Date) {
    setSelectedDate(formatDateISO(date))
    setModalDate(date)
    setModalOpen(true)
  }

  async function handleSaveEvent(payload: EventPayload, existingId?: string) {
    if (existingId) {
      await updateEvent({ id: existingId, payload })
    } else {
      await createEvent(payload)
    }
  }

  async function handleDeleteEvent(id: string) {
    await deleteEvent(id)
  }

  return (
    <div className="flex flex-col gap-4 h-full">
      <header className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
        <div className="space-y-1">
          <h1 className="text-xl font-semibold tracking-tight">Calendar</h1>
          <p className="text-xs text-slate-400">
            {format(currentDate, view === 'year' ? 'yyyy' : 'EEEE, MMM d, yyyy')}
          </p>
        </div>

        <div className="flex flex-col gap-2 md:flex-row md:items-center md:gap-3">
          <nav
            aria-label="Calendar view"
            className="inline-flex rounded-2xl bg-slate-900 border border-slate-800 p-0.5 shadow-inner"
          >
            {(['day', 'week', 'month', 'year'] as const).map((value) => (
              <button
                key={value}
                type="button"
                onClick={() => setView(value)}
                className={[
                  'px-3 py-1.5 text-xs font-medium rounded-2xl capitalize transition',
                  'focus-visible:focus-ring',
                  view === value
                    ? 'bg-gradient-to-r from-purple-500 to-pink-500 text-slate-50 shadow-md'
                    : 'text-slate-300 hover:bg-slate-800',
                ].join(' ')}
              >
                {value}
              </button>
            ))}
          </nav>

          <div className="flex items-center gap-2 self-start md:self-auto">
            <button
              type="button"
              onClick={handlePrev}
              className="h-8 w-8 rounded-xl border border-slate-800 bg-slate-900 flex items-center justify-center text-slate-300 hover:bg-slate-800 hover:shadow-md transition focus-visible:focus-ring"
              aria-label="Previous period"
            >
              ‹
            </button>
            <button
              type="button"
              onClick={handleToday}
              className="px-3 py-1.5 rounded-xl border border-slate-800 bg-slate-900 text-xs font-medium text-slate-50 hover:bg-slate-800 hover:shadow-md transition focus-visible:focus-ring"
            >
              Today
            </button>
            <button
              type="button"
              onClick={handleNext}
              className="h-8 w-8 rounded-xl border border-slate-800 bg-slate-900 flex items-center justify-center text-slate-300 hover:bg-slate-800 hover:shadow-md transition focus-visible:focus-ring"
              aria-label="Next period"
            >
              ›
            </button>
          </div>
        </div>
      </header>

      <section className="flex-1 rounded-2xl border border-slate-800 bg-slate-900/80 shadow-lg overflow-hidden">
        <div className="h-full w-full transition-all duration-300 ease-out">
          {view === 'month' && (
            <MonthView
              date={currentDate}
              events={events}
              onSelectDate={openModalFor}
            />
          )}
          {view === 'day' && (
            <DayView
              date={currentDate}
              events={events}
            />
          )}
          {view === 'week' && (
            <WeekView
              date={currentDate}
              events={events}
            />
          )}
          {view === 'year' && (
            <YearView
              date={currentDate}
              events={events}
              onSelectMonth={(d) => {
                setSelectedDate(formatDateISO(d))
                setView('month')
              }}
            />
          )}
        </div>
      </section>

      <EventModal
        open={modalOpen}
        date={modalDate}
        events={
          modalDate
            ? events.filter((e) => isSameDaySafe(new Date(e.start), modalDate))
            : []
        }
        holiday={modalDate ? getHolidayForDate(modalDate) : null}
        loading={isLoading}
        error={error}
        onClose={() => setModalOpen(false)}
        onSave={handleSaveEvent}
        onDelete={handleDeleteEvent}
      />
    </div>
  )
}

function formatDateISO(date: Date) {
  return date.toISOString().slice(0, 10)
}

function getRangeForView(date: Date, view: CalendarView) {
  if (view === 'day') {
    const start = startOfDay(date)
    const end = addDays(start, 1)
    return { from: start, to: end }
  }
  if (view === 'week') {
    const start = startOfDay(date)
    const end = addDays(start, 7)
    return { from: start, to: end }
  }
  if (view === 'month') {
    const start = startOfMonth(date)
    const end = endOfMonth(date)
    return { from: start, to: end }
  }
  const start = new Date(date.getFullYear(), 0, 1)
  const end = new Date(date.getFullYear(), 11, 31)
  return { from: start, to: end }
}

function isSameDaySafe(a: Date, b: Date) {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  )
}



