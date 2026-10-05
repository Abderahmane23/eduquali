import { useCallback, useEffect, useRef, useState } from 'react'
import { ApiError } from '../api'

/** Etat d'un chargement asynchrone. */
export interface AsyncState<T> {
  data: T | undefined
  loading: boolean
  error: string | undefined
  reload: () => void
}

/**
 * Charge une valeur et suit son etat.
 *
 * Le message d'erreur est toujours redige a destination de l'utilisateur : il
 * decrit ce qui s'est passe et ne lui reproche rien.
 */
export function useAsync<T>(
  loader: () => Promise<T>,
  deps: unknown[] = [],
): AsyncState<T> {
  const [data, setData] = useState<T>()
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string>()
  const [tick, setTick] = useState(0)

  // Une réponse tardive ne doit pas ecraser un chargement plus recent.
  const runId = useRef(0)

  useEffect(() => {
    const current = ++runId.current
    setLoading(true)
    setError(undefined)

    loader()
      .then((value) => {
        if (runId.current === current) setData(value)
      })
      .catch((cause: unknown) => {
        if (runId.current !== current) return
        setError(
          cause instanceof ApiError
            ? cause.message
            : 'Le chargement n’a pas abouti. Réessayez.',
        )
      })
      .finally(() => {
        if (runId.current === current) setLoading(false)
      })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, tick])

  const reload = useCallback(() => setTick((t) => t + 1), [])

  return { data, loading, error, reload }
}
