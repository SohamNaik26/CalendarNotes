const DB_NAME = 'calendarnotes'
const DB_VERSION = 1
const OUTBOX_STORE = 'outbox'
const META_STORE = 'meta'

export type OutboxChange = {
  id: string
  type: 'event' | 'note' | 'task' | 'bookmark'
  action: 'create' | 'update' | 'delete'
  payload: unknown
  timestamp: number
}

async function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = window.indexedDB.open(DB_NAME, DB_VERSION)
    request.onerror = () => reject(request.error)
    request.onsuccess = () => resolve(request.result)
    request.onupgradeneeded = () => {
      const db = request.result
      if (!db.objectStoreNames.contains(OUTBOX_STORE)) {
        db.createObjectStore(OUTBOX_STORE, { keyPath: 'id' })
      }
      if (!db.objectStoreNames.contains(META_STORE)) {
        db.createObjectStore(META_STORE, { keyPath: 'key' })
      }
    }
  })
}

export async function loadOutbox(): Promise<OutboxChange[]> {
  const db = await openDb()
  return new Promise((resolve, reject) => {
    const tx = db.transaction(OUTBOX_STORE, 'readonly')
    const store = tx.objectStore(OUTBOX_STORE)
    const request = store.getAll()
    request.onsuccess = () => resolve(request.result as OutboxChange[])
    request.onerror = () => reject(request.error)
  })
}

export async function saveOutbox(changes: OutboxChange[]) {
  const db = await openDb()
  return new Promise<void>((resolve, reject) => {
    const tx = db.transaction(OUTBOX_STORE, 'readwrite')
    const store = tx.objectStore(OUTBOX_STORE)
    store.clear()
    changes.forEach((change) => store.put(change))
    tx.oncomplete = () => resolve()
    tx.onerror = () => reject(tx.error)
  })
}

export async function getLastSyncVersion(): Promise<number | null> {
  const db = await openDb()
  return new Promise((resolve, reject) => {
    const tx = db.transaction(META_STORE, 'readonly')
    const store = tx.objectStore(META_STORE)
    const request = store.get('lastSyncVersion')
    request.onsuccess = () => {
      const result = request.result as { key: string; value: number } | undefined
      resolve(result?.value ?? null)
    }
    request.onerror = () => reject(request.error)
  })
}

export async function setLastSyncVersion(value: number) {
  const db = await openDb()
  return new Promise<void>((resolve, reject) => {
    const tx = db.transaction(META_STORE, 'readwrite')
    const store = tx.objectStore(META_STORE)
    store.put({ key: 'lastSyncVersion', value })
    tx.oncomplete = () => resolve()
    tx.onerror = () => reject(tx.error)
  })
}


