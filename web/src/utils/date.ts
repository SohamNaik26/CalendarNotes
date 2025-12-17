import { format, startOfDay } from 'date-fns'

export function formatDay(date: Date) {
  return format(startOfDay(date), 'yyyy-MM-dd')
}


