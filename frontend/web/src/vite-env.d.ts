/// <reference types="vite/client" />

interface ImportMetaEnv {
  /**
   * Projet Supabase interroge directement par le navigateur.
   *
   * Les deux vont ensemble : une seule des deux est une configuration a
   * moitie faite, et l'application repart alors sur son backend simule.
   */
  readonly VITE_SUPABASE_URL?: string

  /**
   * Cle « anon » de Supabase — publique par construction.
   *
   * Elle est ecrite en clair dans le bundle. La securite repose entierement
   * sur RLS ; cette cle ne fait qu'identifier le projet. La cle
   * `service_role` n'a rien a faire ici : elle passe outre RLS.
   */
  readonly VITE_SUPABASE_ANON_KEY?: string

  /** URL de l'API REST (§47). Ignoree si Supabase est configure. */
  readonly VITE_API_BASE_URL?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
