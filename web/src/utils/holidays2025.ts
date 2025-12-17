export type Holiday = {
  date: string // yyyy-MM-dd
  name: string
  isIndian: boolean
  isInternational: boolean
}

export const HOLIDAYS_2025: Holiday[] = [
  // Indian holidays
  { date: '2025-01-26', name: 'Republic Day', isIndian: true, isInternational: false },
  { date: '2025-03-14', name: 'Holi', isIndian: true, isInternational: false },
  {
    date: '2025-08-15',
    name: 'Independence Day (India)',
    isIndian: true,
    isInternational: false,
  },
  { date: '2025-10-21', name: 'Diwali', isIndian: true, isInternational: false },
  { date: '2025-10-02', name: 'Gandhi Jayanti', isIndian: true, isInternational: false },

  // International holidays
  { date: '2025-01-01', name: "New Year's Day", isIndian: false, isInternational: true },
  { date: '2025-12-25', name: 'Christmas Day', isIndian: false, isInternational: true },
  { date: '2025-04-18', name: 'Good Friday', isIndian: false, isInternational: true },
  { date: '2025-04-20', name: 'Easter Sunday', isIndian: false, isInternational: true },
]

export function getHolidayForDate(date: Date): Holiday | null {
  const iso = date.toISOString().slice(0, 10)
  return HOLIDAYS_2025.find((h) => h.date === iso) ?? null
}
