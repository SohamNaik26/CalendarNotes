export type User = {
  id: string
  name: string
  email: string
}

export type CalendarEvent = {
  id: string
  title: string
  notes?: string
  start: string
  end: string
}

export type Note = {
  id: string
  title: string
  content: string
  createdAt: string
  updatedAt: string
  tags?: string[]
  linkedDate?: string
  linkedEventId?: string
}

export type Task = {
  id: string
  title: string
  done: boolean
  description?: string
  dueDate?: string
  priority?: 'high' | 'medium' | 'low'
  category?: string
  recurrence?: 'none' | 'daily' | 'weekly' | 'monthly'
  linkedEventId?: string
  createdAt: string
  updatedAt: string
}

export type Bookmark = {
  id: string
  title: string
  url: string
  createdAt: string
  description?: string
  tags?: string[]
  collectionId?: string
  color?: string
  iconEmoji?: string
}


