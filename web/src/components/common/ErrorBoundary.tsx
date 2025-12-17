import { Component, type ErrorInfo, type ReactNode } from 'react'
import { reportError } from '../../utils/errorReporting'

type Props = {
  children: ReactNode
}

type State = {
  hasError: boolean
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props)
    this.state = { hasError: false }
  }

  static getDerivedStateFromError() {
    return { hasError: true }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    reportError(error, info)
  }

  handleRetry = () => {
    this.setState({ hasError: false })
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="flex h-full min-h-[40vh] flex-col items-center justify-center gap-2 text-center text-sm text-slate-200">
          <p className="text-base font-semibold">Something went wrong</p>
          <p className="max-w-sm text-xs text-slate-400">
            An unexpected error occurred while rendering this page. You can try again.
          </p>
          <button
            type="button"
            onClick={this.handleRetry}
            className="mt-2 rounded-lg bg-gradient-to-r from-purple-500 to-pink-500 px-3 py-1.5 text-xs font-medium text-slate-50 shadow-md hover:shadow-lg focus-visible:focus-ring"
          >
            Retry
          </button>
        </div>
      )
    }

    return this.props.children
  }
}


