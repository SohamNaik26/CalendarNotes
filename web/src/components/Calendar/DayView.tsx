import { addHours, format, isWithinInterval, startOfDay } from 'date-fns'
import type { CalendarEvent } from './Calendar'

type DayViewProps = {
  date: Date
  events: CalendarEvent[]
}

const HOURS = Array.from({ length: 24 }, (_, i) => i)

export function DayView({ date, events }: DayViewProps) {
  const dayStart = startOfDay(date)

  const dayEvents = events.filter((event) => {
    const start = new Date(event.start)
    const end = new Date(event.end)
    return isWithinInterval(dayStart, { start: startOfDay(start), end })
  })

  const now = new Date()
  const isToday =
    now.toDateString() === dayStart.toDateString() && now >= dayStart

  const minutesFromStart = isToday
    ? (now.getHours() * 60 + now.getMinutes()) / (24 * 60)
    : 0

  return (
    <div className="h-full flex overflow-hidden">
      <div className="w-14 shrink-0 border-r border-slate-800 bg-slate-900/80 text-[0.65rem] text-slate-500">
        {HOURS.map((hour) => (
          <div
            key={hour}
            className="h-12 pr-1 text-right"
          >
            {format(addHours(dayStart, hour), 'haaa')}
          </div>
        ))}
      </div>

      <div className="relative flex-1 overflow-y-auto bg-slate-950/60">
        <div className="relative h-[72rem]">
          {isToday && (
            <div
              className="absolute left-0 right-0 z-10 flex items-center"
              style={{ top: `${minutesFromStart * 100}%` }}
            >
              <div className="h-2 w-2 rounded-full bg-gradient-to-r from-purple-500 to-pink-500 shadow-md" />
              <div className="ml-1 h-px flex-1 bg-gradient-to-r from-purple-500/80 to-transparent" />
            </div>
          )}

          {dayEvents.map((event) => {
            const start = new Date(event.start)
            const end = new Date(event.end)
            const startMinutes =
              start.getHours() * 60 + start.getMinutes()
            const endMinutes = end.getHours() * 60 + end.getMinutes()
            const top = (startMinutes / (24 * 60)) * 100
            const height = Math.max((endMinutes - startMinutes) / (24 * 60) * 100, 3)

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
                className="absolute inset-x-2 rounded-xl bg-gradient-to-br shadow-md text-[0.65rem] px-2 py-1 text-slate-50 hover:shadow-xl hover:scale-[1.01] transition-transform"
                style={{ top: `${top}%`, height: `${height}%` }}
              >
                <p className="font-medium truncate">{event.title}</p>
                <p className="opacity-80">
                  {format(start, 'p')} – {format(end, 'p')}
                </p>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}


