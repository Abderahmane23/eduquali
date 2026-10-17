import { describe, expect, it } from 'vitest'

import { messageConnexion, messageInscription } from './auth-erreurs'

/**
 * Ce qu'on dit quand l'inscription échoue.
 *
 * Signalé le 17/10 : Supabase répondait `429` au dernier écran du parcours,
 * et l'écran affichait « Ce numéro a peut-être déjà un compte. Essayez de
 * vous connecter. » La personne allait se connecter à un compte qui
 * n'existait pas, la connexion échouait aussi, et le parcours s'arrêtait là.
 *
 * Un message faux coûte plus cher qu'un message vague : il envoie quelque
 * part. Ces tests tiennent chaque cause sur sa phrase.
 */

describe('l’inscription dit ce qui s’est passé', () => {
  it('une limite de débit n’est pas un compte existant', () => {
    /*
     * Le défaut d'origine. Dans un cybercafé ou derrière le partage de
     * connexion d'un téléphone, plusieurs personnes sortent par la même
     * adresse : la limite se touche sans que personne n'ait rien fait de
     * mal.
     */
    for (const echec of [
      { status: 429 },
      { status: 429, message: 'Request rate limit reached' },
      { message: 'over_request_rate_limit' },
      { code: 'over_email_send_rate_limit' },
    ]) {
      const v = messageInscription(echec)
      expect(v.status, JSON.stringify(echec)).toBe(429)
      expect(v.message).toMatch(/Attendez quelques minutes/)
      expect(v.message).not.toMatch(/déjà un compte/)
    }
  })

  it('et un compte existant le dit sans « peut-être »', () => {
    // « Peut-être » laissait la personne dans le doute sur le geste à faire.
    const v = messageInscription({
      status: 422,
      message: 'User already registered',
    })
    expect(v.status).toBe(409)
    expect(v.message).toMatch(/déjà un compte/)
    expect(v.message).not.toMatch(/peut-être/)
  })

  it('un mot de passe trop simple dit quoi corriger', () => {
    const v = messageInscription({
      status: 422,
      code: 'weak_password',
      message: 'Password should be at least 6 characters',
    })
    expect(v.status).toBe(400)
    expect(v.message).toMatch(/six caractères/)
  })

  it('un refus sur l’adresse parle du numéro, pas de l’adresse', () => {
    /*
     * Le numéro est transformé en adresse de courriel avant d'être envoyé.
     * La personne ignore l'existence de cette adresse : lui parler d'un
     * « email invalide » la laisserait chercher un champ qu'elle n'a jamais
     * rempli.
     */
    const v = messageInscription({
      status: 400,
      message: 'Email address "x@y" is invalid',
    })
    expect(v.message).toMatch(/numéro/)
    expect(v.message).not.toMatch(/mail/i)
  })

  it('une panne serveur dit que le compte n’a pas été créé', () => {
    // C'est la seule question que se pose la personne : dois-je recommencer,
    // ou ai-je déjà un compte à moitié fait ?
    const v = messageInscription({ status: 503 })
    expect(v.status).toBe(502)
    expect(v.message).toMatch(/n’a pas été créé/)
  })

  it('et une cause inconnue rend le texte du serveur, pas une devinette', () => {
    const v = messageInscription({ status: 400, message: 'quelque chose' })
    expect(v.message).toContain('quelque chose')
  })

  it('sans message, elle reste vague mais ne désigne rien', () => {
    const v = messageInscription({})
    expect(v.message).toMatch(/Réessayez/)
    expect(v.message).not.toMatch(/déjà un compte/)
  })
})

describe('la connexion ne dit pas quels numéros ont un compte', () => {
  it('un seul message pour numéro inconnu et mot de passe faux', () => {
    /*
     * La seule ambiguïté qu'on garde volontairement : les distinguer dirait
     * à un inconnu quels numéros ont un compte, et le geste à faire est le
     * même dans les deux cas.
     */
    for (const echec of [
      { status: 400, message: 'Invalid login credentials' },
      { status: 400, message: 'User not found' },
    ]) {
      expect(messageConnexion(echec).message).toBe(
        'Numéro ou mot de passe incorrect.',
      )
    }
  })

  it('mais une limite de débit se dit, là aussi', () => {
    // Sinon la personne croit s'être trompée de mot de passe et le change —
    // ce qui ne règle rien et lui fait perdre celui qu'elle connaissait.
    const v = messageConnexion({ status: 429 })
    expect(v.status).toBe(429)
    expect(v.message).toMatch(/Attendez quelques minutes/)
  })
})
