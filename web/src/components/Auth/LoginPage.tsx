import { FormEvent, useState } from 'react'
import { useLocation, useNavigate, Link } from 'react-router-dom'
import { useAuth } from '../../hooks/useAuth'

type LocationState = {
  from?: { pathname: string }
}

export function LoginPage() {
  const { login, authenticating, error } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const state = location.state as LocationState | null

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [formError, setFormError] = useState<string | null>(null)

  const from = state?.from?.pathname ?? '/'

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    setFormError(null)

    if (!email || !password) {
      setFormError('Email and password are required.')
      return
    }

    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      setFormError('Please enter a valid email address.')
      return
    }

    try {
      await login(email, password)
      navigate(from, { replace: true })
    } catch {
      // error message is handled in context
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-950 px-4">
      <div className="w-full max-w-md rounded-2xl border border-slate-800 bg-slate-900/80 p-6 shadow-lg">
        <h1 className="text-xl font-semibold tracking-tight mb-1">Sign in</h1>
        <p className="text-sm text-slate-400 mb-4">
          Welcome back to CalendarNotes.
        </p>

        <form onSubmit={handleSubmit} className="space-y-4" noValidate>
          <div className="space-y-1.5">
            <label htmlFor="email" className="text-sm font-medium text-slate-200">
              Email
            </label>
            <input
              id="email"
              name="email"
              type="email"
              autoComplete="email"
              required
              className="w-full rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-50 outline-none focus-visible:focus-ring"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>

          <div className="space-y-1.5">
            <label htmlFor="password" className="text-sm font-medium text-slate-200">
              Password
            </label>
            <input
              id="password"
              name="password"
              type="password"
              autoComplete="current-password"
              required
              className="w-full rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-50 outline-none focus-visible:focus-ring"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>

          <div className="flex items-center justify-between text-xs">
            <Link
              to="/reset-password"
              className="text-slate-400 hover:text-slate-100 underline-offset-2 hover:underline"
            >
              Forgot password?
            </Link>
          </div>

          {(formError || error) && (
            <p className="text-xs text-red-400" role="alert">
              {formError ?? error}
            </p>
          )}

          <button
            type="submit"
            disabled={authenticating}
            className="w-full rounded-lg bg-brand-500 px-3 py-2 text-sm font-medium text-slate-50 shadow-sm hover:bg-brand-600 disabled:opacity-60 disabled:cursor-not-allowed focus-visible:focus-ring"
          >
            {authenticating ? 'Signing in…' : 'Sign in'}
          </button>
        </form>

        <p className="mt-4 text-xs text-slate-400">
          Need an account?{' '}
          <Link
            to="/register"
            className="text-slate-100 underline-offset-2 hover:underline"
          >
            Sign up
          </Link>
        </p>
      </div>
    </div>
  )
}


