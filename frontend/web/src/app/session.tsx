import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import { api, isSupabaseBackend } from '../api'
import type { RegisterInput } from '../api/client'
import type { Session } from '../api/types'

/** Session utilisateur, conservee entre deux visites. */

const STORAGE_KEY = 'veriprof.session'

interface SessionContextValue {
  session: Session | null
  ready: boolean
  login(phone: string, password: string): Promise<void>
  register(input: RegisterInput): Promise<void>
  logout(): void
}

const SessionContext = createContext<SessionContextValue | null>(null)

export function SessionProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [ready, setReady] = useState(false)

  useEffect(() => {
    let vivant = true

    // La copie locale sert d'affichage immediat : sans elle, un rechargement
    // montre l'ecran d'accueil une fraction de seconde avant de retrouver la
    // session, et cela ressemble a une deconnexion.
    try {
      const stored = localStorage.getItem(STORAGE_KEY)
      if (stored) setSession(JSON.parse(stored) as Session)
    } catch {
      // Un stockage indisponible (navigation privee) ne doit pas empecher
      // l'application de demarrer : on repart d'une session vide.
    }

    // Puis on demande a qui de droit. Quand l'authentification vit ailleurs
    // — Supabase detient le jeton et le rafraichit — la copie locale n'est
    // qu'un souvenir : elle survit a une expiration, a une revocation et a
    // une deconnexion faite dans un autre onglet.
    void (async () => {
      try {
        const confirmed = await api.currentSession()
        if (!vivant) return
        // `null` rendu par le backend simule ne veut pas dire « deconnecte » :
        // il n'a simplement pas de session a rendre. On ne jette donc la
        // copie locale que si l'implementation en tient vraiment une.
        if (confirmed) persistRef.current(confirmed)
        else if (isSupabaseBackend) persistRef.current(null)
      } catch {
        // Serveur injoignable : on garde ce qu'on affichait. Deconnecter
        // quelqu'un parce que le reseau a hoquete serait pire que le mal.
      } finally {
        if (vivant) setReady(true)
      }
    })()

    return () => {
      vivant = false
    }
  }, [])

  const persist = useCallback((next: Session | null) => {
    setSession(next)
    try {
      if (next) localStorage.setItem(STORAGE_KEY, JSON.stringify(next))
      else localStorage.removeItem(STORAGE_KEY)
    } catch {
      /* sans persistance, la session reste valable le temps de l'onglet */
    }
  }, [])

  const persistRef = useRef(persist)
  persistRef.current = persist

  const value = useMemo<SessionContextValue>(
    () => ({
      session,
      ready,
      login: async (phone, password) => {
        persist(await api.login(phone, password))
      },
      register: async (input) => {
        persist(await api.register(input))
      },
      logout: () => {
        // On oublie d'abord, on previent ensuite : si le reseau tombe, le
        // compte doit quand meme etre quitte sur cet appareil. Un telephone
        // se prete.
        persist(null)
        void api.logout()
      },
    }),
    [session, ready, persist],
  )

  return (
    <SessionContext.Provider value={value}>{children}</SessionContext.Provider>
  )
}

export function useSession(): SessionContextValue {
  const context = useContext(SessionContext)
  if (!context) throw new Error('useSession hors SessionProvider')
  return context
}
