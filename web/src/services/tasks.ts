import { apiClient } from './apiClient'
import type { Task } from '../types'

export type TaskPayload = {
  title: string
  description?: string
  dueDate?: string
  priority?: 'high' | 'medium' | 'low'
  category?: string
  recurrence?: 'none' | 'daily' | 'weekly' | 'monthly'
  linkedEventId?: string
  done?: boolean
}

export type TasksQuery = {
  completed?: boolean
  dueDate?: string
  priority?: 'high' | 'medium' | 'low'
}

export async function fetchTasks(params: TasksQuery) {
  const response = await apiClient.get<Task[]>('/api/todos', {
    params,
  })
  return response.data
}

export async function createTask(payload: TaskPayload) {
  const response = await apiClient.post<Task>('/api/todos', payload)
  return response.data
}

export async function updateTask(id: string, payload: Partial<TaskPayload>) {
  const response = await apiClient.put<Task>(`/api/todos/${id}`, payload)
  return response.data
}

export async function deleteTask(id: string) {
  await apiClient.delete(`/api/todos/${id}`)
  return { id }
}


