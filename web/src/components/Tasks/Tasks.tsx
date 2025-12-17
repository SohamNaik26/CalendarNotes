import { useEffect, useState } from 'react'
import { addDays, parseISO } from 'date-fns'
import { useTasks } from '../../hooks/useTasks'
import { TasksListView } from './TasksListView'
import { TaskEditor } from './TaskEditor'
import type { Task } from '../../types'

export function Tasks() {
  const [editorOpen, setEditorOpen] = useState(false)
  const [editingTask, setEditingTask] = useState<Task | null>(null)

  const { tasks, categories, isLoading, error, createTask, updateTask } = useTasks({})

  useEffect(() => {
    if (!('Notification' in window)) return
    if (Notification.permission === 'default') {
      void Notification.requestPermission()
    }
    if (Notification.permission !== 'granted') return

    const now = new Date()
    const soon = addDays(now, 1)

    tasks
      .filter((t) => !t.done && t.dueDate)
      .forEach((t) => {
        const due = parseISO(t.dueDate!)
        if (due > now && due < soon) {
          const timeout = Math.max(0, due.getTime() - now.getTime())
          setTimeout(() => {
            // eslint-disable-next-line no-new
            new Notification('Task due soon', {
              body: t.title,
            })
          }, timeout)
        }
      })
  }, [tasks])

  function openEditor(task?: Task) {
    setEditingTask(task ?? null)
    setEditorOpen(true)
  }

  async function handleSave(payload: {
    id?: string
    title: string
    description?: string
    dueDate?: string
    priority?: 'high' | 'medium' | 'low'
    category?: string
    recurrence?: 'none' | 'daily' | 'weekly' | 'monthly'
    linkedEventId?: string
  }) {
    if (payload.id) {
      await updateTask({ id: payload.id, payload })
    } else {
      await createTask(payload)
    }
  }

  async function handleToggleDone(task: Task, nextDone: boolean) {
    await updateTask({ id: task.id, payload: { done: nextDone } })

    if (
      !task.done &&
      nextDone &&
      task.recurrence &&
      task.recurrence !== 'none' &&
      task.dueDate
    ) {
      const currentDue = parseISO(task.dueDate)
      let nextDue: Date | null = null
      if (task.recurrence === 'daily') nextDue = addDays(currentDue, 1)
      else if (task.recurrence === 'weekly') nextDue = addDays(currentDue, 7)
      else if (task.recurrence === 'monthly') {
        nextDue = new Date(
          currentDue.getFullYear(),
          currentDue.getMonth() + 1,
          currentDue.getDate(),
        )
      }

      if (nextDue) {
        await createTask({
          title: task.title,
          description: task.description,
          dueDate: nextDue.toISOString().slice(0, 10),
          priority: task.priority,
          category: task.category,
          recurrence: task.recurrence,
          linkedEventId: task.linkedEventId,
        })
      }
    }
  }

  return (
    <div className="flex h-full flex-col gap-3">
      <div className="flex items-baseline justify-between gap-2">
        <h1 className="text-xl font-semibold tracking-tight">Tasks</h1>
        {isLoading && (
          <span className="text-[0.65rem] text-slate-500">
            Syncing tasks…
          </span>
        )}
        {error && (
          <span className="text-[0.65rem] text-red-400">
            Unable to load tasks. Please try again.
          </span>
        )}
      </div>

      <TasksListView
        tasks={tasks}
        onToggleDone={handleToggleDone}
        onEditTask={openEditor}
      />

      <TaskEditor
        open={editorOpen}
        task={editingTask}
        categories={categories}
        onClose={() => setEditorOpen(false)}
        onSave={handleSave}
      />
    </div>
  )
}


