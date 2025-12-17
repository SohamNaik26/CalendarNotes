import { create } from 'zustand'

type AppState = {
  selectedDate: string
  view: 'day' | 'week' | 'month' | 'year'
  setSelectedDate: (date: string) => void
  setView: (view: AppState['view']) => void
}

export const useAppStore = create<AppState>((set) => ({
  selectedDate: new Date().toISOString().slice(0, 10),
  view: 'month',
  setSelectedDate: (date) => set({ selectedDate: date }),
  setView: (view) => set({ view }),
}))


