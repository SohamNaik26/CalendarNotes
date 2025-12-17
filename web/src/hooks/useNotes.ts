import { useMemo } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { Note } from '../types'
import {
  createNote,
  deleteNote,
  fetchNotes,
  updateNote,
  type NotePayload,
  type NotesQuery,
} from '../services/notes'

export function useNotes(query: NotesQuery) {
  const queryClient = useQueryClient()

  const queryResult = useQuery({
    queryKey: ['notes', query],
    queryFn: () => fetchNotes(query),
  })

  const allTags = useMemo(() => {
    const set = new Set<string>()
    ;(queryResult.data ?? []).forEach((note) => {
      note.tags?.forEach((tag) => set.add(tag))
    })
    return Array.from(set).sort()
  }, [queryResult.data])

  const createMutation = useMutation({
    mutationFn: (payload: NotePayload) => createNote(payload),
    onMutate: async (payload) => {
      await queryClient.cancelQueries({ queryKey: ['notes'] })
      const key = ['notes', query] as const
      const prev = queryClient.getQueryData<Note[]>(key) ?? []
      const optimistic: Note = {
        id: `optimistic-${Date.now()}`,
        title: payload.title,
        content: payload.content,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        tags: payload.tags,
        linkedDate: payload.linkedDate,
        linkedEventId: payload.linkedEventId,
      }
      queryClient.setQueryData<Note[]>(key, [...prev, optimistic])
      return { prev }
    },
    onError: (_err, _vars, ctx) => {
      if (ctx?.prev) {
        queryClient.setQueryData(['notes', query], ctx.prev)
      }
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['notes'] })
    },
  })

  const updateMutation = useMutation({
    mutationFn: (vars: { id: string; payload: Partial<NotePayload> }) =>
      updateNote(vars.id, vars.payload),
    onMutate: async ({ id, payload }) => {
      await queryClient.cancelQueries({ queryKey: ['notes'] })
      const key = ['notes', query] as const
      const prev = queryClient.getQueryData<Note[]>(key) ?? []
      queryClient.setQueryData<Note[]>(key, (old = []) =>
        old.map((note) =>
          note.id === id
            ? {
                ...note,
                title: payload.title ?? note.title,
                content: payload.content ?? note.content,
                tags: payload.tags ?? note.tags,
                linkedDate: payload.linkedDate ?? note.linkedDate,
                linkedEventId: payload.linkedEventId ?? note.linkedEventId,
                updatedAt: new Date().toISOString(),
              }
            : note,
        ),
      )
      return { prev }
    },
    onError: (_err, _vars, ctx) => {
      if (ctx?.prev) {
        queryClient.setQueryData(['notes', query], ctx.prev)
      }
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['notes'] })
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => deleteNote(id),
    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: ['notes'] })
      const key = ['notes', query] as const
      const prev = queryClient.getQueryData<Note[]>(key) ?? []
      queryClient.setQueryData<Note[]>(key, (old = []) =>
        old.filter((note) => note.id !== id),
      )
      return { prev }
    },
    onError: (_err, _vars, ctx) => {
      if (ctx?.prev) {
        queryClient.setQueryData(['notes', query], ctx.prev)
      }
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['notes'] })
    },
  })

  return {
    notes: (queryResult.data ?? []) as Note[],
    allTags,
    isLoading: queryResult.isLoading,
    error: queryResult.error,
    createNote: createMutation.mutateAsync,
    updateNote: updateMutation.mutateAsync,
    deleteNote: deleteMutation.mutateAsync,
  }
}


