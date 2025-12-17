import { useToastContext } from '../context/ToastContext'

export function useToast() {
  const { showToast } = useToastContext()
  return {
    success: (message: string) => showToast({ type: 'success', message }),
    error: (message: string) => showToast({ type: 'error', message }),
    info: (message: string) => showToast({ type: 'info', message }),
  }
}


