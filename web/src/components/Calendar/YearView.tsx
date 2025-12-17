import {
  addMonths,
  endOfMonth,
  format,
  isWithinInterval,
  startOfMonth,
} from 'date-fns'
import type { CalendarEvent } from './Calendar'

type YearViewProps = {
  date: Date
  events: CalendarEvent[]
  onSelectMonth: (date: Date) => void
}

export function YearView({ date, events, onSelectMonth }: YearViewProps) {
  const yearStart = startOfMonth(new Date(date.getFullYear(), 0, 1))

  const months: Date[] = []
  for (let i = 0; i < 12; i += 1) {
    months.push(addMonths(yearStart, i))
  }

  return (
    <div className="h-full flex flex-col">
      <div className="grid grid-cols-3 md:grid-cols-4 gap-3 p-3">
        {months.map((month) => {
          const start = startOfMonth(month)
          const end = endOfMonth(month)

          const monthEvents = events.filter((event) => {
            const startDate = new Date(event.start)
            return isWithinInterval(startDate, { start, end })
          })

          return (
            <button
              key={month.toISOString()}
              type="button"
              onClick={() => onSelectMonth(month)}
              className="group rounded-2xl border border-slate-800 bg-slate-950/70 p-3 shadow-md hover:shadow-xl hover:scale-[1.01] transition-transform text-left"
            >
              <div className="flex items-center justify-between mb-2">
                <p className="text-xs font-medium text-slate-200">
                  {format(month, 'MMM')}
                </p>
                {monthEvents.length > 0 && (
                  <span className="inline-flex items-center rounded-full bg-gradient-to-r from-purple-500 to-pink-500 px-2 py-0.5 text-[0.6rem] font-medium text-slate-50 shadow">
                    {monthEvents.length} events
                  </span>
                )}
              </div>
              <MiniMonth month={month} />
            </button>
          )
        })}
      </div>
    </div>
  )
}

function MiniMonth({ month }: { month: Date }) {
  const start = startOfMonth(month)
  const daysInMonth = endOfMonth(month).getDate()

  const days = Array.from({ length: daysInMonth }, (_, i) => i + 1)

  return (
    <div className="grid grid-cols-7 gap-0.5 text-[0.5rem] text-slate-400">
      {days.map((day) => (
        <div
          key={day}
          className="flex h-4 w-4 items-center justify-center rounded-md bg-slate-900/50 group-hover:bg-slate-800/80"
        >
          {day}
        </div>
      ))}
    </div>
  )
}


