import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  createCollection,
  fetchCollections,
  type Collection,
  type CollectionPayload,
} from '../services/collections'

export function useCollections() {
  const queryClient = useQueryClient()

  const queryResult = useQuery({
    queryKey: ['collections'],
    queryFn: fetchCollections,
  })

  const createMutation = useMutation({
    mutationFn: (payload: CollectionPayload) => createCollection(payload),
    onMutate: async (payload) => {
      await queryClient.cancelQueries({ queryKey: ['collections'] })
      const key = ['collections'] as const
      const prev = queryClient.getQueryData<Collection[]>(key) ?? []
      const optimistic: Collection = {
        id: `optimistic-${Date.now()}`,
        ...payload,
      }
      queryClient.setQueryData<Collection[]>(key, [...prev, optimistic])
      return { prev }
    },
    onError: (_err, _vars, ctx) => {
      if (ctx?.prev) {
        queryClient.setQueryData(['collections'], ctx.prev)
      }
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['collections'] })
    },
  })

  return {
    collections: (queryResult.data ?? []) as Collection[],
    isLoading: queryResult.isLoading,
    error: queryResult.error,
    createCollection: createMutation.mutateAsync,
  }
}


