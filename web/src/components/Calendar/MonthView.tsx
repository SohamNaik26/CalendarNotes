import {
  addDays,
  endOfMonth,
  format,
  isSameDay,
  isSameMonth,
  startOfMonth,
  startOfWeek,
} from 'date-fns'
import { useState } from 'react'
import type { CalendarEvent } from './Calendar'

const WEEKDAYS = ['S', 'M', 'T', 'W', 'T', 'F', 'S']

type MonthViewProps = {
  date: Date
  events: CalendarEvent[]
  onSelectDate: (date: Date) => void
}

export function MonthView({ date, events, onSelectDate }: MonthViewProps) {
  const [modalDay, setModalDay] = useState<Date | null>(null)

  const start = startOfWeek(startOfMonth(date), { weekStartsOn: 0 })
  const end = addDays(endOfMonth(date), 6)

  const days: Date[] = []
  let current = start
  while (days.length < 42 && current <= end) {
    days.push(current)
    current = addDays(current, 1)
  }

  return (
    <div className="h-full flex flex-col">
      <div className="grid grid-cols-7 border-b border-slate-800 bg-slate-900/80 text-xs text-slate-400">
        {WEEKDAYS.map((day) => (
          <div
            key={day}
            className="py-2 text-center font-medium"
          >
            {day}
          </div>
        ))}
      </div>

      <div className="flex-1 grid grid-cols-7 grid-rows-6 text-xs">
        {days.map((day) => {
          const isToday = isSameDay(day, new Date())
          const inMonth = isSameMonth(day, date)

          const dayEvents = events.filter((event) => {
            const startDate = new Date(event.start)
            return isSameDay(startDate, day)
          })

          const indianHoliday = dayEvents.some((e) => e.isIndianHoliday)
          const internationalHoliday = dayEvents.some((e) => e.isInternationalHoliday)

          const visibleDots = dayEvents.slice(0, 3)
          const remaining = dayEvents.length - visibleDots.length

          const cellGradient =
            indianHoliday || internationalHoliday
              ? 'bg-gradient-to-br from-purple-500/30 via-pink-500/20 to-orange-400/20'
              : ''

          return (
            <button
              key={day.toISOString()}
              type="button"
              onClick={() => {
                onSelectDate(day)
                setModalDay(day)
              }}
              className={[
                'relative flex flex-col items-start justify-start p-1.5 border border-slate-900/60 transition',
                cellGradient,
                'hover:bg-slate-800/70 hover:shadow-lg hover:scale-[1.01]',
                !inMonth && 'text-slate-500/70',
              ]
                .filter(Boolean)
                .join(' ')}
            >
              <div className="flex items-center gap-1">
                <div
                  className={[
                    'inline-flex h-6 w-6 items-center justify-center rounded-full text-[0.7rem] font-medium',
                    isToday
                      ? 'bg-slate-950 text-slate-50 ring-2 ring-offset-2 ring-offset-slate-900 ring-purple-500/80'
                      : 'text-slate-200',
                  ].join(' ')}
                >
                  {format(day, 'd')}
                </div>

                {(indianHoliday || internationalHoliday) && (
                  <div className="flex gap-0.5">
                    {indianHoliday && (
                      <span className="h-1.5 w-1.5 rounded-full bg-orange-400" />
                    )}
                    {internationalHoliday && (
                      <span className="h-1.5 w-1.5 rounded-full bg-pink-400" />
                    )}
                  </div>
                )}
              </div>

              <div className="mt-1 flex flex-wrap gap-0.5">
                {visibleDots.map((event) => (
                  <span
                    key={event.id}
                    className="h-1.5 w-1.5 rounded-full bg-purple-400/80"
                  />
                ))}
                {remaining > 0 && (
                  <span className="text-[0.6rem] text-slate-300">+{remaining}</span>
                )}
              </div>
            </button>
          )
        })}
      </div>

      {modalDay && (
        <div
          className="fixed inset-0 z-30 flex items-end justify-center bg-black/40 p-4 md:items-center"
          role="dialog"
          aria-modal="true"
        >
          <div className="w-full max-w-md rounded-2xl bg-slate-950/95 border border-slate-800 shadow-xl p-4">
            <div className="flex items-center justify-between mb-2">
              <div>
                <p className="text-xs text-slate-400">Events on</p>
                <p className="text-sm font-semibold text-slate-50">
                  {format(modalDay, 'EEEE, MMM d, yyyy')}
                </p>
              </div>
              <button
                type="button"
                onClick={() => setModalDay(null)}
                className="h-7 w-7 rounded-full border border-slate-700 text-slate-300 hover:bg-slate-800 focus-visible:focus-ring text-xs"
                aria-label="Close events"
              >
                ✕
              </button>
            </div>
            <div className="mt-2 max-h-60 overflow-y-auto space-y-2">
              {events
                .filter((event) => isSameDay(new Date(event.start), modalDay))
                .map((event) => (
                  <div
                    key={event.id}
                    className="rounded-xl bg-gradient-to-r from-purple-500/80 to-pink-500/70 px-3 py-2 text-xs text-slate-50 shadow-md"
                  >
                    <p className="font-medium truncate">{event.title}</p>
                    <p className="opacity-80">
                      {format(new Date(event.start), 'p')} –{' '}
                      {format(new Date(event.end), 'p')}
                    </p>
                  </div>
                ))}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}


