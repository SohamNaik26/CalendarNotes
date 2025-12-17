import axios from 'axios'
import { API_BASE_URL } from '../utils/env'
import {
  clearTokens,
  getStoredTokens,
  isTokenExpired,
  saveTokens,
  type TokenPayload,
} from '../utils/authStorage'

export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true,
})

apiClient.interceptors.request.use((config) => {
  const stored = getStoredTokens()
  if (stored && !isTokenExpired(stored)) {
    config.headers = {
      ...config.headers,
      Authorization: `Bearer ${stored.accessToken}`,
    }
  }
  return config
})

let isRefreshing = false
let refreshPromise: Promise<void> | null = null

async function refreshTokens() {
  const stored = getStoredTokens()
  if (!stored?.refreshToken) {
    clearTokens()
    return
  }

  const response = await axios.post<{ tokens: TokenPayload }>(
    `${API_BASE_URL}/api/auth/refresh-token`,
    { refreshToken: stored.refreshToken },
    { withCredentials: true },
  )

  saveTokens(response.data.tokens)
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
apiClient.interceptors.response.use(undefined, async (error: any) => {
  const status = error?.response?.status
  const originalRequest = error?.config

  if (status === 401 && originalRequest && !originalRequest._retry) {
    originalRequest._retry = true

    if (!isRefreshing) {
      isRefreshing = true
      refreshPromise = refreshTokens().finally(() => {
        isRefreshing = false
      })
    }

    try {
      await refreshPromise
      const stored = getStoredTokens()
      if (stored && !isTokenExpired(stored)) {
        originalRequest.headers = {
          ...originalRequest.headers,
          Authorization: `Bearer ${stored.accessToken}`,
        }
        return apiClient(originalRequest)
      }
    } catch {
      clearTokens()
    }
  }

  return Promise.reject(error)
})



