import { createContext, useContext, useState, useEffect, type ReactNode } from 'react'
import type { User } from '../types'
import {
  fetchCurrentUser,
  login as loginRequest,
  logout as logoutRequest,
  register as registerRequest,
} from '../services/auth'
import { getStoredTokens, isTokenExpired, clearTokens } from '../utils/authStorage'

type AuthContextValue = {
  user: User | null
  initializing: boolean
  authenticating: boolean
  error: string | null
  login: (email: string, password: string) => Promise<void>
  register: (name: string, email: string, password: string) => Promise<void>
  logout: () => Promise<void>
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [initializing, setInitializing] = useState(true)
  const [authenticating, setAuthenticating] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false

    async function bootstrap() {
      const stored = getStoredTokens()
      if (!stored || isTokenExpired(stored)) {
        clearTokens()
        setInitializing(false)
        return
      }

      try {
        const currentUser = await fetchCurrentUser()
        if (!cancelled) {
          setUser(currentUser)
        }
      } catch {
        if (!cancelled) {
          clearTokens()
          setUser(null)
        }
      } finally {
        if (!cancelled) {
          setInitializing(false)
        }
      }
    }

    void bootstrap()

    return () => {
      cancelled = true
    }
  }, [])

  async function login(email: string, password: string) {
    setAuthenticating(true)
    setError(null)
    try {
      const loggedInUser = await loginRequest({ email, password })
      setUser(loggedInUser)
    } catch (err) {
      setError('Unable to sign in. Please check your credentials and try again.')
      throw err
    } finally {
      setAuthenticating(false)
    }
  }

  async function register(name: string, email: string, password: string) {
    setAuthenticating(true)
    setError(null)
    try {
      const newUser = await registerRequest({ name, email, password })
      setUser(newUser)
    } catch (err) {
      setError('Unable to register with those details. Please try again.')
      throw err
    } finally {
      setAuthenticating(false)
    }
  }

  async function logout() {
    setAuthenticating(true)
    setError(null)
    try {
      await logoutRequest()
      setUser(null)
    } finally {
      setAuthenticating(false)
    }
  }

  return (
    <AuthContext.Provider
      value={{
        user,
        initializing,
        authenticating,
        error,
        login,
        register,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}

export function useAuthContext() {
  const ctx = useContext(AuthContext)
  if (!ctx) {
    throw new Error('useAuthContext must be used within an AuthProvider')
  }
  return ctx
}
