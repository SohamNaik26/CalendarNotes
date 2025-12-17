import { FormEvent, useState } from 'react'
import { Link } from 'react-router-dom'
import { apiClient } from '../../services/apiClient'

export function PasswordResetPage() {
  const [email, setEmail] = useState('')
  const [submitted, setSubmitted] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    setError(null)

    if (!email) {
      setError('Email is required.')
      return
    }

    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      setError('Please enter a valid email address.')
      return
    }

    setLoading(true)
    try {
      // Adjust endpoint if your backend uses a different path
      await apiClient.post('/api/auth/request-password-reset', { email })
      setSubmitted(true)
    } catch {
      setError('Unable to start password reset. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-950 px-4">
      <div className="w-full max-w-md rounded-2xl border border-slate-800 bg-slate-900/80 p-6 shadow-lg">
        <h1 className="text-xl font-semibold tracking-tight mb-1">Reset password</h1>
        <p className="text-sm text-slate-400 mb-4">
          Enter your email and we&apos;ll send you a reset link.
        </p>

        {submitted ? (
          <p className="text-sm text-slate-200">
            If there&apos;s an account associated with <span className="font-medium">{email}</span>, you&apos;ll receive an email shortly with instructions.
          </p>
        ) : (
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

            {error && (
              <p className="text-xs text-red-400" role="alert">
                {error}
              </p>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full rounded-lg bg-brand-500 px-3 py-2 text-sm font-medium text-slate-50 shadow-sm hover:bg-brand-600 disabled:opacity-60 disabled:cursor-not-allowed focus-visible:focus-ring"
            >
              {loading ? 'Sending reset link…' : 'Send reset link'}
            </button>
          </form>
        )}

        <p className="mt-4 text-xs text-slate-400">
          Remembered your password?{' '}
          <Link
            to="/login"
            className="text-slate-100 underline-offset-2 hover:underline"
          >
            Back to sign in
          </Link>
        </p>
      </div>
    </div>
  )
}


