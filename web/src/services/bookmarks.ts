import { apiClient } from './apiClient'
import type { Bookmark } from '../types'

export type BookmarkPayload = {
  url: string
  title?: string
  description?: string
  tags?: string[]
  collectionId?: string
  color?: string
  iconEmoji?: string
}

export type BookmarksQuery = {
  collectionId?: string
  tags?: string[]
  search?: string
}

export async function fetchBookmarks(params: BookmarksQuery) {
  const response = await apiClient.get<Bookmark[]>('/api/bookmarks', { params })
  return response.data
}

export async function createBookmark(payload: BookmarkPayload) {
  const response = await apiClient.post<Bookmark>('/api/bookmarks', payload)
  return response.data
}

export async function updateBookmark(id: string, payload: Partial<BookmarkPayload>) {
  const response = await apiClient.put<Bookmark>(`/api/bookmarks/${id}`, payload)
  return response.data
}

export async function deleteBookmark(id: string) {
  await apiClient.delete(`/api/bookmarks/${id}`)
  return { id }
}


