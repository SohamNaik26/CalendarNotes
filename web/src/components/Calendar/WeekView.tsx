import {
  addDays,
  endOfWeek,
  format,
  isSameDay,
  isWithinInterval,
  startOfDay,
  startOfWeek,
} from 'date-fns'
import type { CalendarEvent } from './Calendar'

type WeekViewProps = {
  date: Date
  events: CalendarEvent[]
}

export function WeekView({ date, events }: WeekViewProps) {
  const start = startOfWeek(date, { weekStartsOn: 0 })
  const end = endOfWeek(date, { weekStartsOn: 0 })

  const days: Date[] = []
  let current = start
  while (current <= end) {
    days.push(current)
    current = addDays(current, 1)
  }

  const byDay = days.map((day) => {
    const dayStart = startOfDay(day)
    const dayEnd = addDays(dayStart, 1)
    const dayEvents = events.filter((event) => {
      const startDate = new Date(event.start)
      const endDate = new Date(event.end)
      return isWithinInterval(startDate, { start: dayStart, end: dayEnd }) ||
        isWithinInterval(dayStart, { start: startDate, end: endDate })
    })
    return { day, events: dayEvents }
  })

  return (
    <div className="h-full flex flex-col">
      <div className="grid grid-cols-7 border-b border-slate-800 bg-slate-900/80 text-xs">
        {byDay.map(({ day }) => {
          const isToday = isSameDay(day, new Date())
          return (
            <div
              key={day.toISOString()}
              className="px-2 py-2 text-center"
            >
              <div
                className={[
                  'inline-flex flex-col items-center justify-center rounded-xl px-2 py-1',
                  isToday
                    ? 'bg-gradient-to-r from-purple-500 to-pink-500 text-slate-50 shadow-md'
                    : 'text-slate-300',
                ].join(' ')}
              >
                <span className="text-[0.65rem] uppercase tracking-wide">
                  {format(day, 'EEE')}
                </span>
                <span className="text-sm font-semibold">
                  {format(day, 'd')}
                </span>
              </div>
            </div>
          )
        })}
      </div>

      <div className="flex-1 grid grid-cols-7 gap-px bg-slate-900/60 p-1 text-xs">
        {byDay.map(({ day, events: dayEvents }) => {
          const visible = dayEvents.slice(0, 2)
          const remaining = dayEvents.length - visible.length

          return (
            <div
              key={day.toISOString()}
              className="rounded-xl bg-slate-950/60 border border-slate-900/70 p-1.5 flex flex-col gap-1"
            >
              {visible.map((event) => {
                const color =
                  event.category === 'work'
                    ? 'from-sky-500/80 to-sky-400/70'
                    : event.category === 'personal'
                    ? 'from-emerald-500/80 to-emerald-400/70'
                    : event.category === 'health'
                    ? 'from-red-500/80 to-red-400/70'
                    : 'from-purple-500/80 to-pink-500/70'

                return (
                  <div
                    key={event.id}
                    className={[
                      'rounded-lg bg-gradient-to-r px-2 py-1 text-[0.65rem] text-slate-50 shadow-md',
                      'hover:shadow-lg hover:scale-[1.02] transition-transform',
                      color,
                    ].join(' ')}
                  >
                    <p className="font-medium truncate">{event.title}</p>
                  </div>
                )
              })}
              {remaining > 0 && (
                <span className="text-[0.6rem] text-slate-400">
                  +{remaining} more
                </span>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}


