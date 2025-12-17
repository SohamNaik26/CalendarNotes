import { describe, expect, it } from 'vitest'
import { formatDay } from './date'

describe('formatDay', () => {
  it('formats date to yyyy-MM-dd', () => {
    const date = new Date('2025-01-02T10:20:30Z')
    expect(formatDay(date)).toBe('2025-01-02')
  })
})


