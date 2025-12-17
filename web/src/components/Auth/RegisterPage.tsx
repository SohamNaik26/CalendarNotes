import { FormEvent, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../../hooks/useAuth'

export function RegisterPage() {
  const { register, authenticating, error } = useAuth()
  const navigate = useNavigate()

  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [formError, setFormError] = useState<string | null>(null)

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    setFormError(null)

    if (!name || !email || !password) {
      setFormError('Name, email, and password are required.')
      return
    }

    if (password.length < 8) {
      setFormError('Password must be at least 8 characters long.')
      return
    }

    try {
      await register(name, email, password)
      navigate('/', { replace: true })
    } catch {
      // context error message will be shown
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-950 px-4">
      <div className="w-full max-w-md rounded-2xl border border-slate-800 bg-slate-900/80 p-6 shadow-lg">
        <h1 className="text-xl font-semibold tracking-tight mb-1">Create account</h1>
        <p className="text-sm text-slate-400 mb-4">
          Join CalendarNotes to organize your day.
        </p>

        <form onSubmit={handleSubmit} className="space-y-4" noValidate>
          <div className="space-y-1.5">
            <label htmlFor="name" className="text-sm font-medium text-slate-200">
              Name
            </label>
            <input
              id="name"
              name="name"
              type="text"
              required
              className="w-full rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-50 outline-none focus-visible:focus-ring"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </div>

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
              autoComplete="new-password"
              required
              className="w-full rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-50 outline-none focus-visible:focus-ring"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
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
            {authenticating ? 'Creating account…' : 'Create account'}
          </button>
        </form>

        <p className="mt-4 text-xs text-slate-400">
          Already have an account?{' '}
          <Link
            to="/login"
            className="text-slate-100 underline-offset-2 hover:underline"
          >
            Sign in
          </Link>
        </p>
      </div>
    </div>
  )
}


