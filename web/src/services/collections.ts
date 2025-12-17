import { apiClient } from './apiClient'

export type Collection = {
  id: string
  name: string
  parentId?: string
  color?: string
  iconEmoji?: string
}

export type CollectionPayload = {
  name: string
  parentId?: string
  color?: string
  iconEmoji?: string
}

export async function fetchCollections() {
  const response = await apiClient.get<Collection[]>('/api/collections')
  return response.data
}

export async function createCollection(payload: CollectionPayload) {
  const response = await apiClient.post<Collection>('/api/collections', payload)
  return response.data
}


