import { useEffect, useMemo, useState } from 'react'
import { useTheme } from '../../hooks/useTheme'
import { useAuth } from '../../hooks/useAuth'
import { useAppStore } from '../../store/useAppStore'
import { apiClient } from '../../services/apiClient'

const ACCENT_COLORS = [
  '#6366f1', // purple
  '#06b6d4', // cyan
  '#22c55e', // green
  '#f97316', // orange
  '#ec4899', // pink
]

type ToggleProps = {
  checked: boolean
  onChange: (value: boolean) => void
  'aria-label'?: string
}

function Toggle({ checked, onChange, 'aria-label': ariaLabel }: ToggleProps) {
  return (
    <button
      type="button"
      onClick={() => onChange(!checked)}
      className={[
        'relative inline-flex h-5 w-9 items-center rounded-full border transition-colors duration-200',
        checked
          ? 'border-purple-500 bg-purple-500/60'
          : 'border-slate-600 bg-slate-800',
      ].join(' ')}
      role="switch"
      aria-checked={checked}
      aria-label={ariaLabel}
    >
      <span
        className={[
          'inline-block h-4 w-4 transform rounded-full bg-slate-950 shadow transition-transform duration-200',
          checked ? 'translate-x-4' : 'translate-x-1',
        ].join(' ')}
      />
    </button>
  )
}

export function Settings() {
  const { theme, setTheme, resolvedTheme } = useTheme()
  const { user, logout } = useAuth()
  const { view, setView } = useAppStore()

  const initials = useMemo(() => {
    if (!user) return 'CN'
    const parts = user.name?.trim().split(' ') ?? []
    if (parts.length === 0) return (user.email ?? 'CN').slice(0, 2).toUpperCase()
    return parts
      .slice(0, 2)
      .map((p) => p[0]?.toUpperCase() ?? '')
      .join('')
  }, [user])

  const [accent, setAccent] = useState<string>(() => {
    return window.localStorage.getItem('calendarnotes:accent') ?? ACCENT_COLORS[0]
  })
  const [compactView, setCompactView] = useState<boolean>(() => {
    return window.localStorage.getItem('calendarnotes:compact') === 'true'
  })
  const [eventReminders, setEventReminders] = useState<boolean>(true)
  const [taskReminders, setTaskReminders] = useState<boolean>(true)
  const [firstDayOfWeek, setFirstDayOfWeek] = useState<'sunday' | 'monday'>('sunday')
  const [timeFormat, setTimeFormat] = useState<'12' | '24'>('12')

  useEffect(() => {
    window.localStorage.setItem('calendarnotes:accent', accent)
  }, [accent])

  useEffect(() => {
    window.localStorage.setItem('calendarnotes:compact', compactView ? 'true' : 'false')
  }, [compactView])

  async function handleExportData() {
    try {
      await apiClient.post('/api/account/export')
      // In a full app, you might trigger a download or toast here.
    } catch {
      // swallow for now; UI stays simple
    }
  }

  async function handleDeleteAccount() {
    if (!window.confirm('Are you sure you want to delete your account?')) return
    try {
      await apiClient.post('/api/account/delete')
      await logout()
    } catch {
      // simple fallback; could show error toast
    }
  }

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Settings</h1>
        <p className="text-sm text-slate-300">
          Configure how CalendarNotes looks and behaves.
        </p>
      </div>

      {/* Profile */}
      <section
        aria-labelledby="profile-heading"
        className="rounded-2xl border border-slate-800 bg-slate-950/80 p-4 shadow-lg"
      >
        <div className="flex items-center gap-4">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-purple-500 to-pink-500 text-sm font-semibold text-slate-50 shadow-md">
            {initials}
          </div>
          <div className="flex-1">
            <h2
              id="profile-heading"
              className="text-sm font-semibold text-slate-50"
            >
              Profile
            </h2>
            <p className="text-sm text-slate-200">
              {user?.name ?? 'CalendarNotes User'}
            </p>
            {user?.email && (
              <p className="text-xs text-slate-400">{user.email}</p>
            )}
          </div>
          <button
            type="button"
            className="rounded-xl border border-slate-700 px-3 py-1.5 text-xs text-slate-200 hover:bg-slate-900 focus-visible:focus-ring"
          >
            Edit profile
          </button>
        </div>
      </section>

      {/* Appearance */}
      <section
        aria-labelledby="appearance-heading"
        className="rounded-2xl border border-slate-800 bg-slate-950/80 p-4 shadow-lg space-y-4"
      >
        <div className="flex items-center gap-2">
          <h2
            id="appearance-heading"
            className="text-sm font-semibold text-slate-50"
          >
            🎨 Appearance
          </h2>
        </div>

        <div className="space-y-3 text-sm">
          <div className="flex flex-wrap items-center gap-3">
            <span className="min-w-[5rem] text-slate-400">Theme</span>
            <div className="inline-flex rounded-xl border border-slate-800 bg-slate-900 p-0.5">
              {(['system', 'light', 'dark'] as const).map((value) => (
                <button
                  key={value}
                  type="button"
                  onClick={() => setTheme(value)}
                  className={[
                    'px-3 py-1 rounded-lg capitalize text-xs font-medium transition',
                    'focus-visible:focus-ring',
                    theme === value
                      ? 'bg-gradient-to-r from-purple-500 to-pink-500 text-slate-50 shadow'
                      : 'text-slate-300 hover:bg-slate-800',
                  ].join(' ')}
                  aria-pressed={theme === value}
                >
                  {value}
                </button>
              ))}
            </div>
            <span className="text-xs text-slate-500">
              Effective: <span className="capitalize">{resolvedTheme}</span>
            </span>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            <span className="min-w-[5rem] text-slate-400">Accent</span>
            <div className="flex flex-wrap gap-2">
              {ACCENT_COLORS.map((color) => (
                <button
                  key={color}
                  type="button"
                  onClick={() => setAccent(color)}
                  className={[
                    'h-6 w-6 rounded-full border-2 transition hover:scale-110 focus-visible:focus-ring',
                    accent === color
                      ? 'border-slate-50'
                      : 'border-slate-700',
                  ].join(' ')}
                  style={{ backgroundColor: color }}
                  aria-label={`Set accent color ${color}`}
                  aria-pressed={accent === color}
                />
              ))}
            </div>
          </div>

          <div className="flex items-center justify-between gap-3">
            <div>
              <p className="text-sm text-slate-200">Compact view</p>
              <p className="text-xs text-slate-500">
                Reduce padding and spacing for dense information.
              </p>
            </div>
            <Toggle
              checked={compactView}
              onChange={setCompactView}
              aria-label="Toggle compact view"
            />
          </div>
        </div>
      </section>

      {/* Notifications */}
      <section
        aria-labelledby="notifications-heading"
        className="rounded-2xl border border-slate-800 bg-slate-950/80 p-4 shadow-lg space-y-3"
      >
        <div className="flex items-center gap-2">
          <h2
            id="notifications-heading"
            className="text-sm font-semibold text-slate-50"
          >
            🔔 Notifications
          </h2>
        </div>

        <div className="space-y-3 text-sm">
          <div className="flex items-center justify-between gap-3">
            <div>
              <p className="text-slate-200">Event reminders</p>
              <p className="text-xs text-slate-500">
                Get notified before calendar events start.
              </p>
            </div>
            <Toggle
              checked={eventReminders}
              onChange={setEventReminders}
              aria-label="Toggle event reminders"
            />
          </div>

          <div className="flex items-center justify-between gap-3">
            <div>
              <p className="text-slate-200">Task reminders</p>
              <p className="text-xs text-slate-500">
                Receive alerts when tasks are due soon.
              </p>
            </div>
            <Toggle
              checked={taskReminders}
              onChange={setTaskReminders}
              aria-label="Toggle task reminders"
            />
          </div>
        </div>
      </section>

      {/* Calendar preferences */}
      <section
        aria-labelledby="calendar-heading"
        className="rounded-2xl border border-slate-800 bg-slate-950/80 p-4 shadow-lg space-y-3"
      >
        <div className="flex items-center gap-2">
          <h2
            id="calendar-heading"
            className="text-sm font-semibold text-slate-50"
          >
            📅 Calendar
          </h2>
        </div>

        <div className="grid gap-3 text-xs md:grid-cols-3">
          <div className="space-y-1">
            <p className="text-slate-200">Default view</p>
            <select
              className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-1.5 text-xs text-slate-50 outline-none focus-visible:focus-ring"
              value={view}
              onChange={(e) =>
                setView(e.target.value as 'day' | 'week' | 'month' | 'year')
              }
            >
              <option value="month">Month</option>
              <option value="week">Week</option>
              <option value="day">Day</option>
              <option value="year">Year</option>
            </select>
          </div>

          <div className="space-y-1">
            <p className="text-slate-200">First day of week</p>
            <select
              className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-1.5 text-xs text-slate-50 outline-none focus-visible:focus-ring"
              value={firstDayOfWeek}
              onChange={(e) =>
                setFirstDayOfWeek(e.target.value as 'sunday' | 'monday')
              }
            >
              <option value="sunday">Sunday</option>
              <option value="monday">Monday</option>
            </select>
          </div>

          <div className="space-y-1">
            <p className="text-slate-200">Time format</p>
            <select
              className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-1.5 text-xs text-slate-50 outline-none focus-visible:focus-ring"
              value={timeFormat}
              onChange={(e) =>
                setTimeFormat(e.target.value as '12' | '24')
              }
            >
              <option value="12">12‑hour (AM/PM)</option>
              <option value="24">24‑hour</option>
            </select>
          </div>
        </div>
      </section>

      {/* Account actions */}
      <section
        aria-labelledby="account-heading"
        className="rounded-2xl border border-slate-800 bg-slate-950/80 p-4 shadow-lg space-y-3"
      >
        <div className="flex items-center gap-2">
          <h2
            id="account-heading"
            className="text-sm font-semibold text-slate-50"
          >
            Account
          </h2>
        </div>

        <div className="space-y-2 text-xs">
          <button
            type="button"
            onClick={logout}
            className="w-full rounded-xl border border-red-500/40 bg-red-500/5 px-3 py-2 text-left font-medium text-red-400 hover:bg-red-500/10 focus-visible:focus-ring"
          >
            Sign out
          </button>

          <button
            type="button"
            onClick={handleExportData}
            className="w-full rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-left font-medium text-slate-200 hover:bg-slate-800 focus-visible:focus-ring"
          >
            Export data
          </button>

          <button
            type="button"
            onClick={handleDeleteAccount}
            className="w-full rounded-xl border border-red-500/40 bg-slate-900 px-3 py-2 text-left font-medium text-red-400 hover:bg-red-500/10 focus-visible:focus-ring"
          >
            Delete account
          </button>
        </div>
      </section>
    </div>
  )
}



