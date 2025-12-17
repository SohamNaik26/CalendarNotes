import { useState, type ComponentType, type SVGProps } from 'react'
import {
  CalendarIcon,
  NotebookPenIcon,
  Settings2Icon,
  CheckSquareIcon,
  BookmarkIcon,
  PlusIcon,
} from 'lucide-react'
import { Route, Routes, NavLink, useLocation, useNavigate } from 'react-router-dom'
import { Calendar } from './components/Calendar/Calendar'
import { Notes } from './components/Notes/Notes'
import { Tasks } from './components/Tasks/Tasks'
import { Bookmarks } from './components/Bookmarks/Bookmarks'
import { Settings } from './components/Settings/Settings'
import { LoginPage } from './components/Auth/LoginPage'
import { RegisterPage } from './components/Auth/RegisterPage'
import { PasswordResetPage } from './components/Auth/PasswordResetPage'
import { EmailVerificationPage } from './components/Auth/EmailVerificationPage'
import { ProtectedRoute } from './components/Auth/ProtectedRoute'
import { useAuth } from './hooks/useAuth'
import { SyncIndicator } from './components/Sync/SyncIndicator'
import { ErrorBoundary } from './components/common/ErrorBoundary'

function App() {
  const { user } = useAuth()
  const location = useLocation()
  const navigate = useNavigate()
  const [addSheetOpen, setAddSheetOpen] = useState(false)

  const isAuthRoute =
    location.pathname === '/login' ||
    location.pathname === '/register' ||
    location.pathname === '/reset-password' ||
    location.pathname === '/verify-email'

  return (
    <div className="min-h-screen bg-slate-950 text-slate-50 flex">
      <aside className="hidden md:flex md:flex-col w-64 border-r border-slate-800 bg-slate-950/80 backdrop-blur">
        <div className="flex items-center gap-2 px-6 py-4 border-b border-slate-800">
          <div className="h-9 w-9 rounded-xl bg-brand-500/10 flex items-center justify-center">
            <CalendarIcon className="h-5 w-5 text-brand-500" aria-hidden="true" />
          </div>
          <div>
            <p className="text-sm font-semibold tracking-tight">CalendarNotes</p>
            <p className="text-xs text-slate-400">Your day, in one place</p>
          </div>
        </div>

        <nav aria-label="Primary" className="flex-1 px-3 py-4 space-y-1">
          <NavItem to="/" icon={CalendarIcon} label="Calendar" />
          <NavItem to="/notes" icon={NotebookPenIcon} label="Notes" />
          <NavItem to="/tasks" label="Tasks" />
          <NavItem to="/bookmarks" label="Bookmarks" />
          <NavItem to="/settings" icon={Settings2Icon} label="Settings" />
        </nav>
      </aside>

      <main className="flex-1 flex flex-col pb-14 md:pb-0">
        <header className="md:hidden flex items-center justify-between px-4 py-3 border-b border-slate-800 bg-slate-950/90 backdrop-blur">
          <div className="flex items-center gap-2">
            <CalendarIcon className="h-5 w-5 text-brand-500" aria-hidden="true" />
            <span className="text-sm font-semibold">CalendarNotes</span>
          </div>
          {user && !isAuthRoute && (
            <div className="ml-2">
              <SyncIndicator />
            </div>
          )}
        </header>

        <section className="flex-1 px-4 py-4 md:px-8 md:py-6">
          <ErrorBoundary>
            <Routes>
              <Route path="/login" element={<LoginPage />} />
              <Route path="/register" element={<RegisterPage />} />
              <Route path="/reset-password" element={<PasswordResetPage />} />
              <Route path="/verify-email" element={<EmailVerificationPage />} />

              <Route element={<ProtectedRoute />}>
                <Route path="/" element={<Calendar />} />
                <Route path="/notes" element={<Notes />} />
                <Route path="/tasks" element={<Tasks />} />
                <Route path="/bookmarks" element={<Bookmarks />} />
                <Route path="/settings" element={<Settings />} />
              </Route>
            </Routes>
          </ErrorBoundary>
        </section>

        {user && !isAuthRoute && (
          <>
            {/* Floating action button */}
            <button
              type="button"
              onClick={() => setAddSheetOpen(true)}
              className="md:hidden fixed bottom-24 right-6 z-30 flex h-14 w-14 items-center justify-center rounded-full bg-gradient-to-br from-purple-500 to-pink-500 text-slate-50 shadow-lg shadow-purple-500/40 hover:scale-110 active:scale-95 transition-transform focus-visible:focus-ring"
              aria-label="Add item"
            >
              <PlusIcon className="h-6 w-6" aria-hidden="true" />
            </button>

            {/* Bottom tab bar */}
            <nav
              aria-label="Bottom navigation"
              className="md:hidden fixed bottom-0 inset-x-0 z-20 border-t border-slate-800 bg-slate-950/95 backdrop-blur px-2 py-1.5"
            >
              <div className="mx-auto flex max-w-md items-center justify-between gap-1">
                <MobileTab to="/" label="Calendar" icon={CalendarIcon} />
                <MobileTab to="/notes" label="Notes" icon={NotebookPenIcon} />
                <MobileTab to="/tasks" label="Tasks" icon={CheckSquareIcon} />
                <MobileTab to="/bookmarks" label="Bookmarks" icon={BookmarkIcon} />
                <MobileTab to="/settings" label="Settings" icon={Settings2Icon} />
              </div>
            </nav>

            {/* Add item bottom sheet */}
            {addSheetOpen && (
              <div
                className="fixed inset-0 z-40 flex items-end justify-center bg-black/40 md:hidden"
                role="dialog"
                aria-modal="true"
                onClick={() => setAddSheetOpen(false)}
              >
                <div
                  className="w-full max-w-md rounded-t-3xl border border-slate-800 bg-slate-950/95 p-4 shadow-2xl transform translate-y-0 transition-transform duration-300 ease-out"
                  onClick={(e) => e.stopPropagation()}
                >
                  <div className="mb-2 flex items-center justify-between">
                    <p className="text-sm font-semibold text-slate-50">
                      Add item
                    </p>
                    <button
                      type="button"
                      onClick={() => setAddSheetOpen(false)}
                      className="h-7 w-7 rounded-full border border-slate-700 text-slate-300 hover:bg-slate-800 focus-visible:focus-ring text-xs"
                      aria-label="Close add item sheet"
                    >
                      ✕
                    </button>
                  </div>
                  <div className="space-y-2 text-sm">
                    <AddItemRow
                      icon={CalendarIcon}
                      label="Add event"
                      onClick={() => {
                        setAddSheetOpen(false)
                        navigate('/')
                      }}
                    />
                    <AddItemRow
                      icon={NotebookPenIcon}
                      label="Add note"
                      onClick={() => {
                        setAddSheetOpen(false)
                        navigate('/notes')
                      }}
                    />
                    <AddItemRow
                      icon={CheckSquareIcon}
                      label="Add task"
                      onClick={() => {
                        setAddSheetOpen(false)
                        navigate('/tasks')
                      }}
                    />
                    <AddItemRow
                      icon={BookmarkIcon}
                      label="Add bookmark"
                      onClick={() => {
                        setAddSheetOpen(false)
                        navigate('/bookmarks')
                      }}
                    />
                  </div>
                </div>
              </div>
            )}
          </>
        )}
      </main>
    </div>
  )
}

type NavItemProps = {
  to: string
  label: string
  icon?: ComponentType<SVGProps<SVGSVGElement>>
}

function NavItem({ to, label, icon: Icon }: NavItemProps) {
  return (
    <NavLink
      to={to}
      end={to === '/'}
      className={({ isActive }) =>
        [
          'flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-colors outline-none',
          'focus-visible:focus-ring',
          isActive
            ? 'bg-brand-500 text-slate-50 shadow-sm'
            : 'text-slate-300 hover:bg-slate-800 hover:text-slate-50',
        ].join(' ')
      }
      aria-label={label}
    >
      {Icon && <Icon className="h-4 w-4" aria-hidden="true" />}
      <span>{label}</span>
    </NavLink>
  )
}

type MobileTabProps = {
  to: string
  label: string
  icon: ComponentType<SVGProps<SVGSVGElement>>
}

function MobileTab({ to, label, icon: Icon }: MobileTabProps) {
  return (
    <NavLink
      to={to}
      end={to === '/'}
      className={({ isActive }) =>
        [
          'flex flex-col items-center justify-center gap-1 rounded-2xl px-2 py-1.5 text-[0.65rem] transition-all duration-150 outline-none min-w-[3.2rem]',
          'focus-visible:focus-ring',
          isActive
            ? 'scale-110 bg-purple-100 text-purple-600 font-medium shadow-sm'
            : 'scale-100 text-slate-400 opacity-60 hover:opacity-100',
        ].join(' ')
      }
      aria-label={label}
    >
      <Icon className="h-4 w-4" aria-hidden="true" />
      <span>{label}</span>
    </NavLink>
  )
}

type AddItemRowProps = {
  icon: ComponentType<SVGProps<SVGSVGElement>>
  label: string
  onClick: () => void
}

function AddItemRow({ icon: Icon, label, onClick }: AddItemRowProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-full items-center gap-3 rounded-2xl border border-slate-800 bg-slate-900/80 px-3 py-2 text-left text-sm text-slate-100 hover:bg-slate-800 hover:shadow-lg hover:scale-[1.01] transition-transform focus-visible:focus-ring"
    >
      <div className="flex h-8 w-8 items-center justify-center rounded-full bg-gradient-to-br from-purple-500/80 to-pink-500/80 text-slate-50 shadow">
        <Icon className="h-4 w-4" aria-hidden="true" />
      </div>
      <span>{label}</span>
    </button>
  )
}

export default App

