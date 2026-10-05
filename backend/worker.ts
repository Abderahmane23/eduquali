/**
 * Point d'entree Cloudflare Workers.
 *
 * Le meme Hono que sur Vercel : seule l'enveloppe change. Workers est
 * preferable ici parce qu'il ne met pas le service en veille — l'offre
 * gratuite de Render endort apres quinze minutes et reveille en trente a
 * cinquante secondes, ce qui, sur une connexion guineenne, fait attendre
 * une minute avant le premier octet.
 *
 * Les variables (`SUPABASE_URL`, `GEMINI_API_KEY`…) arrivent par
 * `process.env`, que `nodejs_compat` remplit a partir des secrets declares
 * dans `wrangler.toml`. Aucune de ces valeurs ne doit apparaitre dans le
 * depot : elles se posent avec `wrangler secret put`.
 */
import { app } from './api/[[...route]]'

/**
 * Le cron : generer les seances des cours en direct.
 *
 * Chaque nuit, un mois d'avance. Le travail est **rejouable** — la contrainte
 * d'unicite `(live_course_id, starts_at)` empeche les doublons — donc une
 * execution manquee se rattrape toute seule au passage suivant, sans curseur a
 * tenir ni etat a reparer.
 *
 * Le meme declenchement sert de battement de coeur au projet Supabase, qui se
 * met en pause apres sept jours sans requete sur l'offre gratuite.
 */
async function scheduled(): Promise<void> {
  const cle = process.env.SUPABASE_SERVICE_ROLE_KEY ?? ''

  /*
   * Deux travaux, et le second ne doit pas dependre du premier.
   *
   * Un `await` en serie ferait sauter le cycle des concours le soir ou la
   * generation des seances echoue — et personne ne verrait le lien. Les points
   * d'un concours termine resteraient non distribues jusqu'a ce que quelqu'un
   * remarque que la generation est en panne depuis une semaine.
   *
   * `allSettled` les isole : chacun reussit ou echoue pour son propre compte, et
   * le journal dit lequel.
   */
  const travaux: { nom: string; chemin: string }[] = [
    { nom: 'generation des seances', chemin: '/api/v1/live/sessions/generate' },
    { nom: 'cycle des concours', chemin: '/api/v1/contests/cycle' },
  ]

  const resultats = await Promise.allSettled(
    travaux.map(async (travail) => {
      const reponse = await app.request(travail.chemin, {
        method: 'POST',
        headers: { 'X-Service-Key': cle },
      })
      return `${travail.nom} : ${reponse.status} ${await reponse.text()}`
    }),
  )

  for (const [index, resultat] of resultats.entries()) {
    if (resultat.status === 'fulfilled') {
      console.log(`[cron] ${resultat.value}`)
    } else {
      console.error(`[cron] ${travaux[index].nom} a echoue`, resultat.reason)
    }
  }
}

export default {
  fetch: app.fetch,
  scheduled,
}
