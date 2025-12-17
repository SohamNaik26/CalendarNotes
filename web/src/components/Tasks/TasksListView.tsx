import { useState } from 'react'
import {
  compareAsc,
  format,
  isAfter,
  isBefore,
  isSameDay,
  parseISO,
} from 'date-fns'
import type { Task } from '../../types'

type SortBy = 'dueDate' | 'priority' | 'created'
type Filter = 'all' | 'active' | 'completed'

type Props = {
  tasks: Task[]
  onToggleDone: (task: Task, nextDone: boolean) => Promise<void>
  onEditTask: (task?: Task) => void
}

const BORDER_COLORS = ['border-sky-500', 'border-emerald-500', 'border-purple-500']

export function TasksListView({ tasks, onToggleDone, onEditTask }: Props) {
  const [filter, setFilter] = useState<Filter>('all')
  const [sortBy, setSortBy] = useState<SortBy>('dueDate')

  const today = new Date()
  const filtered = tasks.filter((task) => {
    if (filter === 'active') return !task.done
    if (filter === 'completed') return task.done
    return true
  })

  const sorted = [...filtered].sort((a, b) => {
    if (sortBy === 'created') {
      return compareAsc(new Date(a.createdAt), new Date(b.createdAt))
    }
    if (sortBy === 'priority') {
      const order: Record<string, number> = { high: 0, medium: 1, low: 2 }
      return (order[a.priority ?? 'medium'] ?? 1) - (order[b.priority ?? 'medium'] ?? 1)
    }
    const ad = a.dueDate ? parseISO(a.dueDate) : null
    const bd = b.dueDate ? parseISO(b.dueDate) : null
    if (!ad && !bd) return 0
    if (!ad) return 1
    if (!bd) return -1
    return compareAsc(ad, bd)
  })

  const completedCount = tasks.filter((t) => t.done).length
  const overdueCount = tasks.filter(
    (t) => !t.done && t.dueDate && isBefore(parseISO(t.dueDate), today),
  ).length

  return (
    <div className="flex h-full flex-col gap-3">
      <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
        <div className="flex items-center gap-2 text-[0.7rem] text-slate-400">
          <span>
            {completedCount} completed · {overdueCount} overdue
          </span>
        </div>
        <div className="flex items-center gap-2 text-[0.7rem]">
          <div className="inline-flex rounded-2xl border border-slate-700 bg-slate-900 p-0.5">
            {(['all', 'active', 'completed'] as const).map((value) => (
              <button
                key={value}
                type="button"
                onClick={() => setFilter(value)}
                className={[
                  'rounded-2xl px-2 py-0.5 capitalize',
                  filter === value
                    ? 'bg-gradient-to-r from-purple-500 to-pink-500 text-slate-50 shadow'
                    : 'text-slate-300 hover:bg-slate-800',
                ].join(' ')}
              >
                {value}
              </button>
            ))}
          </div>

          <select
            className="rounded-xl border border-slate-700 bg-slate-900 px-2 py-1 text-[0.7rem] text-slate-50 outline-none focus-visible:focus-ring"
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value as SortBy)}
          >
            <option value="dueDate">Due date</option>
            <option value="priority">Priority</option>
            <option value="created">Created</option>
          </select>

          <button
            type="button"
            onClick={() => onEditTask(undefined)}
            className="rounded-2xl bg-gradient-to-r from-purple-500 to-pink-500 px-3 py-1.5 text-xs font-medium text-slate-50 shadow-md hover:shadow-lg hover:scale-[1.02] focus-visible:focus-ring"
          >
            New task
          </button>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto rounded-2xl border border-slate-800 bg-slate-950/60 p-2">
        {sorted.length === 0 ? (
          <div className="flex h-full flex-col items-center justify-center text-center text-xs text-slate-500">
            <div className="mb-3 h-14 w-14 rounded-3xl bg-gradient-to-br from-purple-500/20 via-orange-500/10 to-emerald-500/20" />
            <p className="mb-1 font-medium text-slate-200">No tasks here</p>
            <p className="max-w-xs">
              Create a few tasks to keep track of what matters today.
            </p>
          </div>
        ) : (
          <ul className="space-y-2">
            {sorted.map((task, index) => (
              <TaskRow
                key={task.id}
                task={task}
                borderColor={BORDER_COLORS[index % BORDER_COLORS.length]}
                onToggleDone={onToggleDone}
                onEditTask={onEditTask}
              />
            ))}
          </ul>
        )}
      </div>
    </div>
  )
}

type RowProps = {
  task: Task
  borderColor: string
  onToggleDone: (task: Task, nextDone: boolean) => Promise<void>
  onEditTask: (task?: Task) => void
}

function TaskRow({ task, borderColor, onToggleDone, onEditTask }: RowProps) {
  const [swipeX, setSwipeX] = useState(0)
  const [swiping, setSwiping] = useState(false)

  const hasDue = Boolean(task.dueDate)
  const due =
    task.dueDate && task.dueDate.length >= 10 ? parseISO(task.dueDate) : null
  const today = new Date()

  let dueColor = 'text-slate-400'
  if (due) {
    if (isSameDay(due, today)) dueColor = 'text-red-400'
    else if (
      isSameDay(due, new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1))
    )
      dueColor = 'text-orange-400'
    else if (isBefore(due, today)) dueColor = 'text-red-500'
    else if (isAfter(due, today)) dueColor = 'text-emerald-400'
  }

  const priorityLabel = task.priority ?? 'medium'
  const priorityColor =
    priorityLabel === 'high'
      ? 'text-red-400'
      : priorityLabel === 'low'
      ? 'text-slate-400'
      : 'text-amber-400'

  async function handleToggle(done: boolean) {
    await onToggleDone(task, done)
  }

  function onPointerDown(e: React.PointerEvent<HTMLLIElement>) {
    setSwiping(true)
    ;(e.target as HTMLElement).setPointerCapture(e.pointerId)
  }

  function onPointerMove(e: React.PointerEvent<HTMLLIElement>) {
    if (!swiping) return
    setSwipeX(Math.min(64, Math.max(0, swipeX + e.movementX)))
  }

  async function onPointerUp(e: React.PointerEvent<HTMLLIElement>) {
    setSwiping(false)
    ;(e.target as HTMLElement).releasePointerCapture(e.pointerId)
    if (swipeX > 40) {
      await handleToggle(!task.done)
    }
    setSwipeX(0)
  }

  return (
    <li
      className="relative"
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
    >
      <div className="pointer-events-none absolute inset-y-1 left-3 flex items-center text-[0.65rem] text-emerald-400">
        {swipeX > 10 && 'Swipe to complete'}
      </div>
      <div
        className={[
          'flex items-start gap-3 rounded-2xl border-l-4 border-slate-700 bg-slate-900/80 p-3 text-xs text-slate-200 shadow-sm transition-all',
          borderColor,
          'hover:shadow-lg hover:scale-[1.01]',
          task.done && 'opacity-60 line-through',
        ].join(' ')}
        style={{
          transform:
            swiping && swipeX > 0 ? `translateX(${swipeX}px)` : 'translateX(0)',
        }}
      >
        <button
          type="button"
          onClick={() => handleToggle(!task.done)}
          className="mt-0.5 h-4 w-4 rounded border border-slate-600 bg-slate-950 text-purple-500 focus-visible:focus-ring"
          aria-pressed={task.done}
        >
          {task.done && '✓'}
        </button>

        <div className="flex-1 space-y-1">
          <button
            type="button"
            onClick={() => onEditTask(task)}
            className="w-full text-left"
          >
            <p className="text-xs font-medium text-slate-50 line-clamp-1">
              {task.title}
            </p>
            {task.description && (
              <p className="text-[0.7rem] text-slate-300 line-clamp-2">
                {task.description}
              </p>
            )}
          </button>

          <div className="flex flex-wrap items-center gap-2 text-[0.65rem]">
            {hasDue && due && (
              <span className={dueColor}>
                Due {format(due, 'EEE, MMM d')}
              </span>
            )}
            <span className={priorityColor}>
              {priorityLabel === 'high'
                ? '⬆ High'
                : priorityLabel === 'low'
                ? '⬇ Low'
                : '⬌ Medium'}
            </span>
            {task.category && (
              <span className="rounded-full bg-slate-800 px-2 py-0.5 text-slate-300">
                {task.category}
              </span>
            )}
          </div>
        </div>
      </div>
    </li>
  )
}


