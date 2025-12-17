import { useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { apiClient } from '../../services/apiClient'

export function EmailVerificationPage() {
  const [searchParams] = useSearchParams()
  const [status, setStatus] = useState<'idle' | 'verifying' | 'success' | 'error'>(
    'idle',
  )
  const [message, setMessage] = useState<string | null>(null)

  useEffect(() => {
    const token = searchParams.get('token')
    if (!token) {
      setStatus('error')
      setMessage('Missing verification token.')
      return
    }

    async function verify() {
      setStatus('verifying')
      try {
        await apiClient.post('/api/auth/verify-email', { token })
        setStatus('success')
        setMessage('Your email has been verified. You can now sign in.')
      } catch {
        setStatus('error')
        setMessage('Unable to verify your email. The link may have expired.')
      }
    }

    void verify()
  }, [searchParams])

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-950 px-4">
      <div className="w-full max-w-md rounded-2xl border border-slate-800 bg-slate-900/80 p-6 shadow-lg text-center">
        <h1 className="text-xl font-semibold tracking-tight mb-2">
          Email verification
        </h1>
        {status === 'verifying' && (
          <p className="text-sm text-slate-300" aria-live="polite">
            Verifying your email…
          </p>
        )}
        {status !== 'verifying' && message && (
          <p className="text-sm text-slate-300" aria-live="polite">
            {message}
          </p>
        )}

        <div className="mt-4">
          <Link
            to="/login"
            className="inline-flex items-center justify-center rounded-lg bg-brand-500 px-3 py-2 text-sm font-medium text-slate-50 shadow-sm hover:bg-brand-600 focus-visible:focus-ring"
          >
            Go to sign in
          </Link>
        </div>
      </div>
    </div>
  )
}


