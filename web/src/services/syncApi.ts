import { apiClient } from './apiClient'

export type SyncChange = {
  id: string
  type: 'event' | 'note' | 'task' | 'bookmark'
  action: 'create' | 'update' | 'delete'
  payload: unknown
  updatedAt: string
}

export type SyncPushRequest = {
  changes: SyncChange[]
  lastSyncVersion?: number | null
}

export type SyncPushResponse = {
  accepted: string[]
  conflicts: SyncChange[]
  newVersion: number
}

export type SyncPullRequest = {
  sinceVersion?: number | null
}

export type SyncPullResponse = {
  changes: SyncChange[]
  newVersion: number
}

export async function pushChanges(body: SyncPushRequest) {
  const response = await apiClient.post<SyncPushResponse>('/api/sync/push', body)
  return response.data
}

export async function pullChanges(body: SyncPullRequest) {
  const response = await apiClient.post<SyncPullResponse>('/api/sync/pull', body)
  return response.data
}

export async function resolveConflict(change: SyncChange) {
  await apiClient.post('/api/sync/resolve-conflict', { change })
}


