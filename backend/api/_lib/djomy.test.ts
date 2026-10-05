import assert from 'node:assert/strict'
import { createHmac } from 'node:crypto'
import { test } from 'node:test'

import {
  Djomy,
  canTransition,
  normalizeStatus,
  purchaseStatusFor,
  toDjomyPhone,
} from './djomy.ts'

/**
 * Le module Djomy.
 *
 * Ce qui est teste ici est ce qui, en cas d'erreur, coute de l'argent reel :
 * la signature qui garde le webhook, la deduplication des statuts, et le
 * format du numero — un numero mal forme fait echouer le paiement avec un
 * message generique de l'operateur, impossible a diagnostiquer depuis nos
 * journaux.
 */

const config = {
  environment: 'sandbox' as const,
  baseUrl: 'https://exemple.invalid',
  clientId: 'djomy-merchant-001',
  clientSecret: 'secret-de-test',
  webhookSecret: 'secret-de-test',
  countryCode: 'GN',
}

/** La signature telle que Djomy la calcule, avec une autre implementation. */
const signer = (message: string, secret: string) =>
  createHmac('sha256', secret).update(message).digest('hex')

test('le numero passe au format 00224…', () => {
  // Nos numeros sont stockes « +224620000101 » ; Djomy veut « 00224620000101 ».
  assert.equal(toDjomyPhone('+224620000101'), '00224620000101')
  assert.equal(toDjomyPhone('+224 620 00 01 01'), '00224620000101')
  assert.equal(toDjomyPhone('224620000101'), '00224620000101')
  // Deja au bon format : inchange.
  assert.equal(toDjomyPhone('00224620000101'), '00224620000101')
  // Numero local, sans indicatif.
  assert.equal(toDjomyPhone('620000101'), '00224620000101')
})

test('la signature du webhook est verifiee sur le corps brut', async () => {
  const djomy = new Djomy(config)
  // Un corps avec des espaces et un ordre de cles qui ne survivraient pas a une
  // re-serialisation : c'est precisement le piege que la verification sur le
  // texte brut evite.
  const corps = '{ "eventType":"payment.success",  "eventId":"abc" }'
  const bonne = signer(corps, config.webhookSecret)

  assert.equal(await djomy.verifyWebhook(corps, `v1:${bonne}`), true)
  // Le prefixe de version est porte par la configuration du marchand : on
  // accepte aussi la signature nue.
  assert.equal(await djomy.verifyWebhook(corps, bonne), true)
  // Casse differente : l'hexadecimal ne distingue pas.
  assert.equal(await djomy.verifyWebhook(corps, bonne.toUpperCase()), true)
})

test('une signature fausse, absente ou d’un autre corps est refusee', async () => {
  const djomy = new Djomy(config)
  const corps = '{"eventType":"payment.success"}'
  const bonne = signer(corps, config.webhookSecret)

  assert.equal(await djomy.verifyWebhook(corps, undefined), false)
  assert.equal(await djomy.verifyWebhook(corps, 'v1:'), false)
  assert.equal(await djomy.verifyWebhook(corps, `v1:${'0'.repeat(64)}`), false)
  // Signee avec une autre cle.
  assert.equal(
    await djomy.verifyWebhook(corps, `v1:${signer(corps, 'autre-secret')}`),
    false,
  )
  // La bonne signature, mais pour un autre corps : c'est l'attaque qui compte
  // — rejouer une signature valide sur un montant modifie.
  assert.equal(
    await djomy.verifyWebhook('{"eventType":"payment.success","x":1}', `v1:${bonne}`),
    false,
  )
})

test('un secret vide ne valide rien', async () => {
  // Sans configuration, `verifyWebhook` doit refuser au lieu de laisser passer.
  // Une verification desactivee par defaut est une porte ouverte.
  const sansSecret = new Djomy({ ...config, webhookSecret: '' })
  const corps = '{}'
  assert.equal(await sansSecret.verifyWebhook(corps, `v1:${signer(corps, '')}`), false)
})

test('l’etat de l’achat se deduit du type d’evenement', () => {
  assert.equal(purchaseStatusFor('payment.success'), 'PAID')
  assert.equal(purchaseStatusFor('payment.refunded'), 'REFUNDED')
  assert.equal(purchaseStatusFor('payment.cancelled'), 'CANCELLED')
  assert.equal(purchaseStatusFor('payment.failed'), 'FAILED')
  // Expire sans reponse du client : n'a pas abouti.
  assert.equal(purchaseStatusFor('payment.timeout'), 'FAILED')
  assert.equal(purchaseStatusFor('payment.pending'), 'PENDING')
  assert.equal(purchaseStatusFor('payment.created'), 'PENDING')
  assert.equal(purchaseStatusFor('payment.redirected'), 'PENDING')
  // Un `payout.*` ou un type inconnu ne touche pas l'achat.
  assert.equal(purchaseStatusFor('payout.success'), null)
  assert.equal(purchaseStatusFor('payment.inventé'), null)
})

test('un cours paye ne redevient pas impaye', () => {
  // Les webhooks arrivent dans un ordre quelconque. Un `payment.pending` reçu
  // apres un `payment.success` retirerait sinon un cours deja regle.
  assert.equal(canTransition('PAID', 'PENDING'), false)
  assert.equal(canTransition('PAID', 'FAILED'), false)
  assert.equal(canTransition('PAID', 'CANCELLED'), false)
  // Seul un remboursement fait sortir de PAID.
  assert.equal(canTransition('PAID', 'REFUNDED'), true)
  // Un remboursement est definitif.
  assert.equal(canTransition('REFUNDED', 'PAID'), false)
  // Le meme etat deux fois n'est pas une transition.
  assert.equal(canTransition('PENDING', 'PENDING'), false)
  // Un echec peut repartir : le payeur reessaie.
  assert.equal(canTransition('FAILED', 'PENDING'), true)
  assert.equal(canTransition('CANCELLED', 'PAID'), true)
})

test('un statut inconnu vaut PENDING, et ne leve pas', () => {
  // Un paiement en cours mal etiquete reste en attente ; le traiter comme un
  // echec annulerait une vente qui aboutit.
  assert.equal(normalizeStatus('SUCCESS'), 'SUCCESS')
  assert.equal(normalizeStatus('success'), 'SUCCESS')
  assert.equal(normalizeStatus('CANCELED'), 'CANCELLED')
  assert.equal(normalizeStatus(undefined), 'PENDING')
  assert.equal(normalizeStatus('QUELQUE_CHOSE'), 'PENDING')
})

test('la configuration incomplete desactive l’encaissement', () => {
  // Sans compte marchand, la demande d'achat doit s'enregistrer sans appeler
  // personne — et non echouer.
  assert.equal(Djomy.isConfigured({}), false)
  assert.equal(Djomy.isConfigured({ baseUrl: 'https://x', clientId: 'a' }), false)
  assert.equal(Djomy.isConfigured(config), true)
})

test('l’environnement est obligatoire, et jamais devine', () => {
  // Les deux erreurs possibles sont silencieuses : « production » par defaut
  // facturerait de vrais clients depuis un poste de developpement, « sandbox »
  // par defaut laisserait une mise en ligne encaisser dans le vide. D'ou un
  // champ obligatoire plutot qu'une valeur par defaut.
  const sansEnvironnement = {
    baseUrl: config.baseUrl,
    clientId: config.clientId,
    clientSecret: config.clientSecret,
  }
  assert.equal(Djomy.isConfigured(sansEnvironnement), false)

  // Une valeur hors des deux attendues est refusee aussi : une faute de frappe
  // ne doit pas tomber dans un cas par defaut.
  assert.equal(
    Djomy.isConfigured({
      ...sansEnvironnement,
      environment: 'prod' as unknown as 'production',
    }),
    false,
  )
  assert.equal(
    Djomy.isConfigured({ ...sansEnvironnement, environment: 'production' }),
    true,
  )
})

test('le bac a sable se sait, et se dit', () => {
  // L'ecran s'en sert pour afficher « paiement de test ». Sans cela, une
  // demonstration en bac a sable passe pour un encaissement reel.
  assert.equal(new Djomy(config).isSandbox, true)
  assert.equal(new Djomy(config).environment, 'sandbox')

  const prod = new Djomy({ ...config, environment: 'production' })
  assert.equal(prod.isSandbox, false)
  assert.equal(prod.environment, 'production')
})
