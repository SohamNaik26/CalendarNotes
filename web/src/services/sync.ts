import { apiClient } from './apiClient'

export async function triggerFullSync() {
  const response = await apiClient.post('/sync')
  return response.data
}


