import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { createEvent, deleteEvent, fetchEvents, updateEvent, type EventPayload } from '../services/events'
import type { CalendarEvent } from '../types'

type UseEventsOptions = {
  from?: string
  to?: string
}

export function useEvents({ from, to }: UseEventsOptions) {
  const queryClient = useQueryClient()

  const query = useQuery({
    queryKey: ['events', { from, to }],
    queryFn: () => fetchEvents({ from, to }),
  })

  const createMutation = useMutation({
    mutationFn: (payload: EventPayload) => createEvent(payload),
    onMutate: async (payload) => {
      await queryClient.cancelQueries({ queryKey: ['events'] })
      const previous = queryClient.getQueryData<CalendarEvent[]>(['events', { from, to }]) ?? []
      const optimistic: CalendarEvent = {
        id: `optimistic-${Date.now()}`,
        title: payload.title,
        notes: payload.description,
        start: payload.start,
        end: payload.end,
      }
      queryClient.setQueryData<CalendarEvent[]>(['events', { from, to }], [
        ...previous,
        optimistic,
      ])
      return { previous }
    },
    onError: (_err, _variables, context) => {
      if (context?.previous) {
        queryClient.setQueryData(['events', { from, to }], context.previous)
      }
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['events'] })
    },
  })

  const updateMutation = useMutation({
    mutationFn: (vars: { id: string; payload: Partial<EventPayload> }) =>
      updateEvent(vars.id, vars.payload),
    onMutate: async ({ id, payload }) => {
      await queryClient.cancelQueries({ queryKey: ['events'] })
      const key = ['events', { from, to }] as const
      const previous = queryClient.getQueryData<CalendarEvent[]>(key) ?? []
      queryClient.setQueryData<CalendarEvent[]>(key, (old = []) =>
        old.map((event) =>
          event.id === id
            ? {
                ...event,
                title: payload.title ?? event.title,
                notes: payload.description ?? event.notes,
                start: payload.start ?? event.start,
                end: payload.end ?? event.end,
              }
            : event,
        ),
      )
      return { previous }
    },
    onError: (_err, _vars, context) => {
      if (context?.previous) {
        queryClient.setQueryData(['events', { from, to }], context.previous)
      }
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['events'] })
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => deleteEvent(id),
    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: ['events'] })
      const key = ['events', { from, to }] as const
      const previous = queryClient.getQueryData<CalendarEvent[]>(key) ?? []
      queryClient.setQueryData<CalendarEvent[]>(key, (old = []) =>
        old.filter((event) => event.id !== id),
      )
      return { previous }
    },
    onError: (_err, _vars, context) => {
      if (context?.previous) {
        queryClient.setQueryData(['events', { from, to }], context.previous)
      }
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['events'] })
    },
  })

  return {
    events: (query.data ?? []) as CalendarEvent[],
    isLoading: query.isLoading,
    error: query.error,
    createEvent: createMutation.mutateAsync,
    updateEvent: updateMutation.mutateAsync,
    deleteEvent: deleteMutation.mutateAsync,
  }
}


