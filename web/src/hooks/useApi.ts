import { useQuery, UseQueryOptions } from '@tanstack/react-query'
import { apiClient } from '../services/apiClient'

export function useApiQuery<TData = unknown>(
  key: string,
  path: string,
  options?: Omit<UseQueryOptions<TData>, 'queryKey' | 'queryFn'>,
) {
  return useQuery<TData>({
    queryKey: [key, path],
    queryFn: async () => {
      const response = await apiClient.get<TData>(path)
      return response.data
    },
    ...options,
  })
}


