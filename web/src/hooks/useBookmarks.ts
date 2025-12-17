import { useMemo } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { Bookmark } from '../types'
import {
  createBookmark,
  deleteBookmark,
  fetchBookmarks,
  updateBookmark,
  type BookmarkPayload,
  type BookmarksQuery,
} from '../services/bookmarks'

export function useBookmarks(query: BookmarksQuery) {
  const queryClient = useQueryClient()

  const queryResult = useQuery({
    queryKey: ['bookmarks', query],
    queryFn: () => fetchBookmarks(query),
  })

  const tags = useMemo(() => {
    const set = new Set<string>()
    ;(queryResult.data ?? []).forEach((b) => b.tags?.forEach((t) => set.add(t)))
    return Array.from(set).sort()
  }, [queryResult.data])

  const createMutation = useMutation({
    mutationFn: (payload: BookmarkPayload) => createBookmark(payload),
    onMutate: async (payload) => {
      await queryClient.cancelQueries({ queryKey: ['bookmarks'] })
      const key = ['bookmarks', query] as const
      const prev = queryClient.getQueryData<Bookmark[]>(key) ?? []
      const now = new Date().toISOString()
      const optimistic: Bookmark = {
        id: `optimistic-${Date.now()}`,
        url: payload.url,
        title: payload.title ?? payload.url,
        description: payload.description,
        tags: payload.tags,
        collectionId: payload.collectionId,
        color: payload.color,
        iconEmoji: payload.iconEmoji,
        createdAt: now,
      }
      queryClient.setQueryData<Bookmark[]>(key, [...prev, optimistic])
      return { prev }
    },
    onError: (_err, _vars, ctx) => {
      if (ctx?.prev) {
        queryClient.setQueryData(['bookmarks', query], ctx.prev)
      }
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['bookmarks'] })
    },
  })

  const updateMutation = useMutation({
    mutationFn: (vars: { id: string; payload: Partial<BookmarkPayload> }) =>
      updateBookmark(vars.id, vars.payload),
    onMutate: async ({ id, payload }) => {
      await queryClient.cancelQueries({ queryKey: ['bookmarks'] })
      const key = ['bookmarks', query] as const
      const prev = queryClient.getQueryData<Bookmark[]>(key) ?? []
      queryClient.setQueryData<Bookmark[]>(key, (old = []) =>
        old.map((b) =>
          b.id === id
            ? {
                ...b,
                ...payload,
                title: payload.title ?? b.title,
                url: payload.url ?? b.url,
                description: payload.description ?? b.description,
                tags: payload.tags ?? b.tags,
                collectionId: payload.collectionId ?? b.collectionId,
                color: payload.color ?? b.color,
                iconEmoji: payload.iconEmoji ?? b.iconEmoji,
              }
            : b,
        ),
      )
      return { prev }
    },
    onError: (_err, _vars, ctx) => {
      if (ctx?.prev) {
        queryClient.setQueryData(['bookmarks', query], ctx.prev)
      }
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['bookmarks'] })
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => deleteBookmark(id),
    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: ['bookmarks'] })
      const key = ['bookmarks', query] as const
      const prev = queryClient.getQueryData<Bookmark[]>(key) ?? []
      queryClient.setQueryData<Bookmark[]>(key, (old = []) =>
        old.filter((b) => b.id !== id),
      )
      return { prev }
    },
    onError: (_err, _vars, ctx) => {
      if (ctx?.prev) {
        queryClient.setQueryData(['bookmarks', query], ctx.prev)
      }
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['bookmarks'] })
    },
  })

  return {
    bookmarks: (queryResult.data ?? []) as Bookmark[],
    tags,
    isLoading: queryResult.isLoading,
    error: queryResult.error,
    createBookmark: createMutation.mutateAsync,
    updateBookmark: updateMutation.mutateAsync,
    deleteBookmark: deleteMutation.mutateAsync,
  }
}


