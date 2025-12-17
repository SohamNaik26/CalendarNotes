import { useSync } from '../../hooks/useSync'

export function SyncIndicator() {
  const { status, lastSyncedAt, lastError, isOffline, syncNow } = useSync()

  const label =
    status === 'syncing'
      ? 'Syncing…'
      : isOffline
      ? 'Offline'
      : lastSyncedAt
      ? `Synced at ${lastSyncedAt.toLocaleTimeString()}`
      : 'Not synced yet'

  const color =
    status === 'syncing'
      ? 'bg-sky-400'
      : isOffline || status === 'error'
      ? 'bg-red-500'
      : 'bg-emerald-500'

  return (
    <button
      type="button"
      onClick={() => void syncNow()}
      className="inline-flex items-center gap-1 rounded-full border border-slate-700 bg-slate-900/80 px-2 py-0.5 text-[0.65rem] text-slate-200 hover:bg-slate-800 focus-visible:focus-ring"
      aria-label="Sync status"
    >
      <span className={`h-2 w-2 rounded-full ${color}`} aria-hidden="true" />
      <span>{label}</span>
      {lastError && (
        <span className="max-w-[8rem] truncate text-red-400" aria-hidden="true">
          · {lastError}
        </span>
      )}
    </button>
  )
}


