import { useMemo } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { Task } from '../types'
import {
  createTask,
  deleteTask,
  fetchTasks,
  updateTask,
  type TaskPayload,
  type TasksQuery,
} from '../services/tasks'

export function useTasks(query: TasksQuery) {
  const queryClient = useQueryClient()

  const queryResult = useQuery({
    queryKey: ['tasks', query],
    queryFn: () => fetchTasks(query),
  })

  const categories = useMemo(() => {
    const set = new Set<string>()
    ;(queryResult.data ?? []).forEach((task) => {
      if (task.category) set.add(task.category)
    })
    return Array.from(set).sort()
  }, [queryResult.data])

  const createMutation = useMutation({
    mutationFn: (payload: TaskPayload) => createTask(payload),
    onMutate: async (payload) => {
      await queryClient.cancelQueries({ queryKey: ['tasks'] })
      const key = ['tasks', query] as const
      const prev = queryClient.getQueryData<Task[]>(key) ?? []
      const now = new Date().toISOString()
      const optimistic: Task = {
        id: `optimistic-${Date.now()}`,
        title: payload.title,
        description: payload.description,
        dueDate: payload.dueDate,
        priority: payload.priority ?? 'medium',
        category: payload.category,
        recurrence: payload.recurrence ?? 'none',
        linkedEventId: payload.linkedEventId,
        done: payload.done ?? false,
        createdAt: now,
        updatedAt: now,
      }
      queryClient.setQueryData<Task[]>(key, [...prev, optimistic])
      return { prev }
    },
    onError: (_err, _vars, ctx) => {
      if (ctx?.prev) {
        queryClient.setQueryData(['tasks', query], ctx.prev)
      }
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['tasks'] })
    },
  })

  const updateMutation = useMutation({
    mutationFn: (vars: { id: string; payload: Partial<TaskPayload> }) =>
      updateTask(vars.id, vars.payload),
    onMutate: async ({ id, payload }) => {
      await queryClient.cancelQueries({ queryKey: ['tasks'] })
      const key = ['tasks', query] as const
      const prev = queryClient.getQueryData<Task[]>(key) ?? []
      const now = new Date().toISOString()
      queryClient.setQueryData<Task[]>(key, (old = []) =>
        old.map((task) =>
          task.id === id
            ? {
                ...task,
                title: payload.title ?? task.title,
                description: payload.description ?? task.description,
                dueDate: payload.dueDate ?? task.dueDate,
                priority: payload.priority ?? task.priority,
                category: payload.category ?? task.category,
                recurrence: payload.recurrence ?? task.recurrence,
                linkedEventId: payload.linkedEventId ?? task.linkedEventId,
                done: payload.done ?? task.done,
                updatedAt: now,
              }
            : task,
        ),
      )
      return { prev }
    },
    onError: (_err, _vars, ctx) => {
      if (ctx?.prev) {
        queryClient.setQueryData(['tasks', query], ctx.prev)
      }
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['tasks'] })
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => deleteTask(id),
    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: ['tasks'] })
      const key = ['tasks', query] as const
      const prev = queryClient.getQueryData<Task[]>(key) ?? []
      queryClient.setQueryData<Task[]>(key, (old = []) =>
        old.filter((task) => task.id !== id),
      )
      return { prev }
    },
    onError: (_err, _vars, ctx) => {
      if (ctx?.prev) {
        queryClient.setQueryData(['tasks', query], ctx.prev)
      }
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['tasks'] })
    },
  })

  return {
    tasks: (queryResult.data ?? []) as Task[],
    categories,
    isLoading: queryResult.isLoading,
    error: queryResult.error,
    createTask: createMutation.mutateAsync,
    updateTask: updateMutation.mutateAsync,
    deleteTask: deleteMutation.mutateAsync,
  }
}


