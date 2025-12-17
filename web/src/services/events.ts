import { apiClient } from './apiClient'
import type { CalendarEvent } from '../types'

export type EventPayload = {
  title: string
  description?: string
  start: string
  end: string
  location?: string
  category: 'work' | 'personal' | 'health' | 'holiday'
  color?: string
  allDay?: boolean
  recurrence?: 'none' | 'daily' | 'weekly' | 'monthly'
  isIndianHoliday?: boolean
  isInternationalHoliday?: boolean
}

export async function fetchEvents(params: { from?: string; to?: string }) {
  const response = await apiClient.get<CalendarEvent[]>('/api/events', {
    params,
  })
  return response.data
}

export async function createEvent(payload: EventPayload) {
  const response = await apiClient.post<CalendarEvent>('/api/events', payload)
  return response.data
}

export async function updateEvent(id: string, payload: Partial<EventPayload>) {
  const response = await apiClient.put<CalendarEvent>(`/api/events/${id}`, payload)
  return response.data
}

export async function deleteEvent(id: string) {
  await apiClient.delete(`/api/events/${id}`)
  return { id }
}


