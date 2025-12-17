import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import { pullChanges, pushChanges, type SyncChange } from '../services/syncApi'
import {
  getLastSyncVersion,
  loadOutbox,
  saveOutbox,
  setLastSyncVersion,
  type OutboxChange,
} from '../utils/indexedDb'
import { useAuth } from '../hooks/useAuth'

type SyncStatus = 'idle' | 'syncing' | 'offline' | 'error'

type Conflict = SyncChange

type SyncContextValue = {
  status: SyncStatus
  lastSyncedAt: Date | null
  lastError: string | null
  conflicts: Conflict[]
  isOffline: boolean
  enqueueChange: (change: Omit<OutboxChange, 'id' | 'timestamp'>) => void
  syncNow: () => Promise<void>
}

const SyncContext = createContext<SyncContextValue | undefined>(undefined)

export function SyncProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth()
  const [status, setStatus] = useState<SyncStatus>('idle')
  const [lastSyncedAt, setLastSyncedAt] = useState<Date | null>(null)
  const [lastError, setLastError] = useState<string | null>(null)
  const [conflicts, setConflicts] = useState<Conflict[]>([])
  const [outbox, setOutbox] = useState<OutboxChange[]>([])
  const [isOffline, setIsOffline] = useState<boolean>(() => !navigator.onLine)

  useEffect(() => {
    setIsOffline(!navigator.onLine)
    function handleOnline() {
      setIsOffline(false)
    }
    function handleOffline() {
      setIsOffline(true)
    }
    window.addEventListener('online', handleOnline)
    window.addEventListener('offline', handleOffline)
    return () => {
      window.removeEventListener('online', handleOnline)
      window.removeEventListener('offline', handleOffline)
    }
  }, [])

  useEffect(() => {
    if (!user) return
    void (async () => {
      try {
        const [storedOutbox] = await Promise.all([loadOutbox()])
        setOutbox(storedOutbox)
      } catch {
        // ignore
      }
    })()
  }, [user])

  const enqueueChange = useCallback(
    (change: Omit<OutboxChange, 'id' | 'timestamp'>) => {
      const full: OutboxChange = {
        ...change,
        id: `${Date.now()}-${Math.random().toString(16).slice(2)}`,
        timestamp: Date.now(),
      }
      setOutbox((current) => {
        const next = [...current, full]
        void saveOutbox(next)
        return next
      })
    },
    [],
  )

  const syncNow = useCallback(async () => {
    if (!user || isOffline || status === 'syncing') return
    setStatus('syncing')
    setLastError(null)
    try {
      const [lastVersion, queued] = await Promise.all([
        getLastSyncVersion(),
        loadOutbox(),
      ])

      if (queued.length > 0) {
        const pushRes = await pushChanges({
          changes: queued.map((c) => ({
            id: c.id,
            type: c.type,
            action: c.action,
            payload: c.payload,
            updatedAt: new Date(c.timestamp).toISOString(),
          })),
          lastSyncVersion: lastVersion,
        })

        setConflicts(pushRes.conflicts)
        await setLastSyncVersion(pushRes.newVersion)
        await saveOutbox([])
        setOutbox([])
      }

      const pullRes = await pullChanges({ sinceVersion: await getLastSyncVersion() })
      if (pullRes.changes.length > 0) {
        // application code would integrate server changes into local state here
        await setLastSyncVersion(pullRes.newVersion)
      }

      setLastSyncedAt(new Date())
      setStatus('idle')
    } catch (err) {
      setLastError(
        err instanceof Error ? err.message : 'Unable to sync with the server.',
      )
      setStatus(isOffline ? 'offline' : 'error')
    }
  }, [user, isOffline, status])

  useEffect(() => {
    if (!user) return
    if (!isOffline) {
      void syncNow()
    }
    const id = window.setInterval(() => {
      void syncNow()
    }, 5 * 60 * 1000)
    return () => window.clearInterval(id)
  }, [user, isOffline, syncNow])

  const value: SyncContextValue = useMemo(
    () => ({
      status: isOffline ? 'offline' : status,
      lastSyncedAt,
      lastError,
      conflicts,
      isOffline,
      enqueueChange,
      syncNow,
    }),
    [status, lastSyncedAt, lastError, conflicts, isOffline, enqueueChange, syncNow],
  )

  return <SyncContext.Provider value={value}>{children}</SyncContext.Provider>
}

export function useSyncContext() {
  const ctx = useContext(SyncContext)
  if (!ctx) {
    throw new Error('useSyncContext must be used within a SyncProvider')
  }
  return ctx
}


