import { apiClient } from './apiClient'
import type { Note } from '../types'

export type NotePayload = {
  title: string
  content: string
  tags?: string[]
  linkedDate?: string
  linkedEventId?: string
}

export type NotesQuery = {
  search?: string
  tags?: string[]
  linkedDate?: string
}

export async function fetchNotes(params: NotesQuery) {
  const response = await apiClient.get<Note[]>('/api/notes', {
    params,
  })
  return response.data
}

export async function createNote(payload: NotePayload) {
  const response = await apiClient.post<Note>('/api/notes', payload)
  return response.data
}

export async function updateNote(id: string, payload: Partial<NotePayload>) {
  const response = await apiClient.put<Note>(`/api/notes/${id}`, payload)
  return response.data
}

export async function deleteNote(id: string) {
  await apiClient.delete(`/api/notes/${id}`)
  return { id }
}


