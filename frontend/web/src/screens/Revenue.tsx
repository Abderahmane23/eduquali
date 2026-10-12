import { useState } from 'react'
import { revenus, serveurDisponible, type Retrait } from '../api/server'
import { Money, PageHead, StatStrip, Tile, gnf } from '../components/kit'
import {
  Banner,
  Button,
  Card,
  Chip,
  EmptyState,
  Field,
  Select,
  Skeleton,
  TextInput,
} from '../components/ui'
import { useAsync } from '../lib/useAsync'
import { formatDate } from '../lib/format'

/**
 * Les revenus, et comment se faire payer.
 *
 * --- Ce que cette page remplace -----------------------------------------
 *
 * Rien, sur aucun des deux clients. Il n'existait ni route ni écran : un
 * professeur travaillait et ne pouvait pas savoir ce qu'il avait gagné, ni
 * demander à être payé. C'est la page qui décide s'il revient.
 *
 * --- Pourquoi un calcul et non un solde --------------------------------
 *
 * Trois sources alimentent ce qu'il gagne, et aucune n'a la même forme : les
 * places vendues sur ses séances, les achats de ses cours vidéo, les
 * échéances réglées de ses contrats. Un solde stocké devrait être mis à jour
 * par chacun des trois chemins, et le jour où l'un oublie, c'est le solde
 * qu'on croit plutôt que les mouvements.
 *
 * --- Pourquoi une demande et non un virement ---------------------------
 *
 * Le paiement sortant est manuel au lancement : un opérateur regarde, vérifie
 * puis envoie par Orange Money. Automatiser la sortie avant d'avoir vu passer
 * dix virements reviendrait à confier à du code non éprouvé la seule
 * opération qu'on ne peut pas annuler. L'écran le dit — « sous deux jours
 * ouvrés » plutôt qu'un silence.
 */
export function Revenue() {
  const etat = useAsync(() => revenus.lire(), [])
  const [montant, setMontant] = useState('')
  const [canal, setCanal] = useState<'ORANGE' | 'MTN' | 'CASH'>('ORANGE')
  const [last4, setLast4] = useState('')
  const [envoi, setEnvoi] = useState(false)
  const [erreur, setErreur] = useState<string>()
  const [demande, setDemande] = useState<Retrait>()

  if (!serveurDisponible) {
    return (
      <div className="screen stack stack--loose">
        <h1 className="page-title">Mes revenus</h1>
        <Banner tone="warning">
          Cette page calcule vos revenus sur le serveur Eduquali, qui n’est pas
          relié à ce site.
        </Banner>
      </div>
    )
  }

  if (etat.loading) {
    return (
      <div className="screen">
        <Skeleton height={120} count={3} />
      </div>
    )
  }

  if (etat.error || !etat.data) {
    return (
      <div className="screen stack stack--loose">
        <h1 className="page-title">Mes revenus</h1>
        <Banner tone="warning">
          {etat.error ?? 'Lecture impossible pour le moment.'}
        </Banner>
      </div>
    )
  }

  const argent = etat.data
  const enAttente = argent.payouts.find(
    (r) => r.status === 'REQUESTED' || r.status === 'APPROVED',
  )

  const demander = async (event: React.FormEvent) => {
    event.preventDefault()
    const somme = Number(montant.replace(/\s/g, ''))
    if (!Number.isFinite(somme) || somme <= 0) {
      setErreur('Indiquez un montant.')
      return
    }

    setEnvoi(true)
    setErreur(undefined)
    try {
      const creee = await revenus.demander({
        amount: Math.round(somme),
        method: canal,
        last4: last4.length === 4 ? last4 : undefined,
      })
      setDemande(creee)
      setMontant('')
      // Le solde disponible a changé : on relit plutôt que de le recalculer
      // ici. Deux façons de calculer la même somme finissent par diverger.
      etat.reload()
    } catch (cause) {
      setErreur(
        cause instanceof Error
          ? cause.message
          : 'La demande n’a pas abouti. Réessayez.',
      )
    } finally {
      setEnvoi(false)
    }
  }

  return (
    <div className="screen stack stack--loose">
      <PageHead
        title="Mes revenus"
        lede="Ce que vos cours ont rapporté, et ce que vous pouvez retirer maintenant."
        stats={[
          { value: argent.seats, label: 'places vendues' },
          { value: argent.purchases, label: 'cours achetés' },
          { value: gnf(argent.paidOut), label: 'déjà versé' },
        ]}
      />

      <Card>
        <div className="stack stack--tight">
          <span className="section-title" style={{ marginBottom: 0 }}>
            Disponible maintenant
          </span>
          <Money amount={argent.available} />
          {argent.pending > 0 ? (
            <span className="muted small">
              {gnf(argent.pending)} sont déjà engagés dans une demande en
              cours : ils ne sont plus disponibles, et c’est voulu — sans cela,
              la même somme se demanderait deux fois.
            </span>
          ) : argent.available < argent.minimum ? (
            <span className="muted small">
              Le retrait minimum est de {gnf(argent.minimum)}. En dessous, la
              commission du transfert mange la somme.
            </span>
          ) : (
            <span className="muted small">
              Versé par Orange Money ou MTN sous deux jours ouvrés, après
              vérification.
            </span>
          )}
        </div>
      </Card>

      <section className="stack">
        <h2 className="section-title">D’où vient cet argent</h2>
        <StatStrip
          plain
          stats={[
            { value: gnf(argent.earned.live), label: 'cours en direct' },
            { value: gnf(argent.earned.videos), label: 'cours vidéo' },
            { value: gnf(argent.earned.contracts), label: 'contrats' },
          ]}
        />
        <p className="faint micro measure">
          Sur un cours en direct, votre part est de 60 % du prix de chaque
          place. Sur un cours vidéo, la commission est figée à l’achat : en
          baisser le prix plus tard ne change pas ce qui vous a déjà été
          compté.
        </p>
      </section>

      {/* La demande. Masquée quand il y en a déjà une : la base refuse la
          seconde, et montrer un formulaire qui va échouer vaut moins que
          d'expliquer pourquoi il n'y en a pas. */}
      <section className="stack">
        <h2 className="section-title">Demander un retrait</h2>

        {enAttente ? (
          <Banner>
            Une demande de {gnf(enAttente.amount)} est en cours depuis le{' '}
            {formatDate(enAttente.requestedAt)}. Elle doit être réglée avant la
            suivante.
          </Banner>
        ) : argent.available < argent.minimum ? (
          <EmptyState
            icon="wallet"
            title="Pas encore assez"
            message={`Il faut ${gnf(argent.minimum)} pour qu’un virement vaille sa commission. Continuez : chaque place vendue vous en rapproche.`}
          />
        ) : (
          <form className="card stack" onSubmit={demander}>
            <Field
              label="Montant"
              hint={`Entre ${gnf(argent.minimum)} et ${gnf(argent.available)}`}
            >
              <TextInput
                inputMode="numeric"
                value={montant}
                onChange={(e) =>
                  setMontant(e.target.value.replace(/[^0-9\s]/g, ''))
                }
                placeholder={String(argent.available)}
              />
            </Field>

            <Field label="Par quel canal">
              <Select
                value={canal}
                onChange={(e) =>
                  setCanal(e.target.value as 'ORANGE' | 'MTN' | 'CASH')
                }
              >
                <option value="ORANGE">Orange Money</option>
                <option value="MTN">MTN MoMo</option>
                <option value="CASH">En espèces, au bureau</option>
              </Select>
            </Field>

            {canal !== 'CASH' ? (
              <Field
                label="Les 4 derniers chiffres de votre numéro"
                hint="Pour que vous reconnaissiez le vôtre. Nous n’enregistrons jamais le numéro complet."
              >
                <TextInput
                  inputMode="numeric"
                  maxLength={4}
                  value={last4}
                  onChange={(e) =>
                    setLast4(e.target.value.replace(/[^0-9]/g, ''))
                  }
                  placeholder="0101"
                />
              </Field>
            ) : null}

            {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

            <Button type="submit" block disabled={envoi}>
              {envoi ? 'Envoi…' : 'Demander le retrait'}
            </Button>
          </form>
        )}

        {demande ? (
          <Banner>
            Demande enregistrée. Vous serez prévenu dès qu’elle est réglée.
          </Banner>
        ) : null}
      </section>

      {argent.payouts.length > 0 ? (
        <section className="stack stack--tight">
          <h2 className="section-title">Mes demandes</h2>
          {argent.payouts.map((retrait) => (
            <LigneRetrait key={retrait.id} retrait={retrait} />
          ))}
        </section>
      ) : null}
    </div>
  )
}

const ETATS: Record<
  Retrait['status'],
  { texte: string; ton?: 'success' | 'warning' | 'danger' }
> = {
  REQUESTED: { texte: 'en attente' },
  APPROVED: { texte: 'validée, virement en route' },
  PAID: { texte: 'versée', ton: 'success' },
  REJECTED: { texte: 'refusée', ton: 'danger' },
}

const CANAUX: Record<Retrait['method'], string> = {
  ORANGE: 'Orange Money',
  MTN: 'MTN MoMo',
  CASH: 'Espèces',
}

function LigneRetrait({ retrait }: { retrait: Retrait }) {
  const etat = ETATS[retrait.status]
  return (
    <div className="rowitem">
      <Tile
        icon="wallet"
        tone={
          retrait.status === 'PAID'
            ? 'success'
            : retrait.status === 'REJECTED'
              ? 'danger'
              : 'neutral'
        }
      />
      <span className="rowitem__body">
        <span className="rowitem__title">{gnf(retrait.amount)}</span>
        <span className="rowitem__sub">
          {CANAUX[retrait.method]} · demandé le{' '}
          {formatDate(retrait.requestedAt)}
          {/* Un refus sans motif se relit comme une panne. */}
          {retrait.note ? ` — ${retrait.note}` : ''}
        </span>
      </span>
      <span className="rowitem__end">
        <Chip tone={etat.ton}>{etat.texte}</Chip>
      </span>
    </div>
  )
}
