import { apiClient } from './apiClient'
import type { User } from '../types'
import { clearTokens, saveTokens, type TokenPayload } from '../utils/authStorage'

type AuthResponse = {
  user: User
  tokens: TokenPayload
}

type Credentials = {
  email: string
  password: string
}

type RegisterPayload = Credentials & {
  name: string
}

export async function register(payload: RegisterPayload) {
  const response = await apiClient.post<AuthResponse>('/api/auth/register', payload)
  const data = response.data
  saveTokens(data.tokens)
  return data.user
}

export async function login(payload: Credentials) {
  const response = await apiClient.post<AuthResponse>('/api/auth/login', payload)
  const data = response.data
  saveTokens(data.tokens)
  return data.user
}

export async function logout() {
  try {
    await apiClient.post('/api/auth/logout')
  } finally {
    clearTokens()
  }
}

export async function fetchCurrentUser() {
  const response = await apiClient.get<User>('/api/auth/me')
  return response.data
}



