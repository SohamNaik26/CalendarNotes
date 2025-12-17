import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import { createPortal } from 'react-dom'

type ToastType = 'success' | 'error' | 'info'

export type Toast = {
  id: string
  type: ToastType
  message: string
  actionLabel?: string
  onAction?: () => void
}

type ToastContextValue = {
  toasts: Toast[]
  showToast: (toast: Omit<Toast, 'id'>) => void
  dismissToast: (id: string) => void
}

const ToastContext = createContext<ToastContextValue | undefined>(undefined)

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([])

  const showToast = useCallback((toast: Omit<Toast, 'id'>) => {
    const id = `${Date.now()}-${Math.random().toString(16).slice(2)}`
    const full: Toast = { id, ...toast }
    setToasts((current) => [...current, full])
    window.setTimeout(() => {
      setToasts((current) => current.filter((t) => t.id !== id))
    }, 4000)
  }, [])

  const dismissToast = useCallback((id: string) => {
    setToasts((current) => current.filter((t) => t.id !== id))
  }, [])

  const value = useMemo(
    () => ({ toasts, showToast, dismissToast }),
    [toasts, showToast, dismissToast],
  )

  return (
    <ToastContext.Provider value={value}>
      {children}
      {createPortal(
        <div className="fixed inset-x-0 bottom-16 z-50 flex flex-col items-center gap-2 px-2 md:bottom-4 md:items-end md:px-4">
          {toasts.map((toast) => (
            <ToastItem
              key={toast.id}
              toast={toast}
              onDismiss={() => dismissToast(toast.id)}
            />
          ))}
        </div>,
        document.body,
      )}
    </ToastContext.Provider>
  )
}

export function useToastContext() {
  const ctx = useContext(ToastContext)
  if (!ctx) {
    throw new Error('useToastContext must be used within a ToastProvider')
  }
  return ctx
}

function ToastItem({ toast, onDismiss }: { toast: Toast; onDismiss: () => void }) {
  const color =
    toast.type === 'success'
      ? 'border-emerald-500/40 bg-emerald-500/10 text-emerald-50'
      : toast.type === 'error'
      ? 'border-red-500/40 bg-red-500/10 text-red-50'
      : 'border-sky-500/40 bg-sky-500/10 text-sky-50'

  return (
    <div
      className={[
        'flex max-w-xs items-center gap-2 rounded-2xl border px-3 py-2 text-xs shadow-lg backdrop-blur animate-in slide-in-from-bottom',
        color,
      ].join(' ')}
      role="status"
    >
      <span className="flex-1">{toast.message}</span>
      {toast.actionLabel && toast.onAction && (
        <button
          type="button"
          onClick={() => {
            toast.onAction?.()
            onDismiss()
          }}
          className="rounded-lg border border-current px-2 py-0.5 text-[0.65rem] font-medium hover:bg-slate-950/20 focus-visible:focus-ring"
        >
          {toast.actionLabel}
        </button>
      )}
      <button
        type="button"
        onClick={onDismiss}
        className="ml-1 text-[0.7rem] text-slate-200 hover:text-slate-50 focus-visible:focus-ring"
        aria-label="Dismiss notification"
      >
        ✕
      </button>
    </div>
  )
}


