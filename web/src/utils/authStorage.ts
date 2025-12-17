export type StoredTokens = {
  accessToken: string
  refreshToken?: string
  /** Epoch millis when the access token expires */
  expiresAt: number
}

export type TokenPayload = {
  accessToken: string
  refreshToken?: string
  /** Lifetime of the access token in seconds */
  expiresIn: number
}

const STORAGE_KEY = 'calendarnotes:auth'

function encode(value: unknown): string {
  // NOTE: This is NOT real encryption, just a light obfuscation layer.
  // For production, back this with httpOnly cookies and/or proper crypto.
  const json = JSON.stringify(value)
  return window.btoa(json)
}

function decode<T>(value: string): T | null {
  try {
    const json = window.atob(value)
    return JSON.parse(json) as T
  } catch {
    return null
  }
}

export function saveTokens(payload: TokenPayload) {
  const expiresAt = Date.now() + payload.expiresIn * 1000
  const stored: StoredTokens = {
    accessToken: payload.accessToken,
    refreshToken: payload.refreshToken,
    expiresAt,
  }
  window.localStorage.setItem(STORAGE_KEY, encode(stored))
}

export function getStoredTokens(): StoredTokens | null {
  const raw = window.localStorage.getItem(STORAGE_KEY)
  if (!raw) return null
  return decode<StoredTokens>(raw)
}

export function clearTokens() {
  window.localStorage.removeItem(STORAGE_KEY)
}

export function isTokenExpired(tokens: StoredTokens, skewMs = 30_000): boolean {
  return tokens.expiresAt - skewMs <= Date.now()
}


