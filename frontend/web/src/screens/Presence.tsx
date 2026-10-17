import { Link, useNavigate, useParams } from 'react-router-dom'
import { api } from '../api'
import type { PresenceProof } from '../api/types'
import {
  Affiche,
  Annotation,
  BigButton,
  LigneDuTemps,
  Tile,
} from '../components/kit'
import { Banner, Button, Card, Icon, Skeleton } from '../components/ui'
import { timeLabel } from '../lib/slots'
import { useAsync } from '../lib/useAsync'

/**
 * La preuve de présence : l'écran qu'une famille ouvre après chaque séance.
 *
 * --- Pourquoi cet écran existe sur le web -------------------------------
 *
 * C'est le cœur de la promesse — on paie, et on sait. Le serveur sert
 * `GET /live/sessions/:id/presence` depuis le 12/10 et l'application Android
 * le lit ; sur le web, rien ne l'appelait. Une famille sans téléphone Android
 * payait donc une séance sans aucun moyen de vérifier qu'elle avait eu lieu —
 * exactement la situation que le produit prétend corriger.
 *
 * --- Ce qu'il montre, et dans cet ordre ---------------------------------
 *
 *   1. **la réponse**, en une phrase : « Aïssatou était là. » Les deux
 *      derniers mots sont surlignés — c'est le geste de la marque, et c'est
 *      la seule chose qu'on vient lire ;
 *   2. « Présent ! » dans l'écriture du cahier, une fois ;
 *   3. les minutes en grand, puis la ligne du temps qui dit **quand** ;
 *   4. trois faits, pas plus : l'heure d'arrivée, les points de contrôle,
 *      ce qui a été travaillé ;
 *   5. la mention « Compté par EduQuali, pas déclaré par l'élève » ;
 *   6. **un seul bouton** : réserver la séance suivante, ou rattraper.
 *
 * --- Ce qu'il ne montre pas ---------------------------------------------
 *
 * Ni note, ni classement, ni comparaison avec les autres élèves. La charte
 * l'écrit comme un interdit, et la raison tient en une ligne : EduQuali
 * promet ce qu'il mesure — un professeur présent, quinze places, des minutes
 * comptées — et rien d'autre.
 */
export function Presence() {
  const { id = '' } = useParams()
  const etat = useAsync(() => api.presenceProof(id), [id])

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
        <h1 className="page-title">La séance</h1>
        <Banner tone="warning">
          {etat.error ??
            'La preuve de présence n’a pas pu être lue. Réessayez dans un ' +
              'instant.'}
        </Banner>
        <Link className="btn btn--ghost" to="/seances">
          Revenir à mes séances
        </Link>
      </div>
    )
  }

  const preuve = etat.data
  const etaitLa = preuve.minutesAttended > 0

  return (
    <div className="screen screen--narrow stack stack--loose">
      <p className="etiquette">La séance</p>

      <Reponse preuve={preuve} />

      {etaitLa ? <Minutes preuve={preuve} /> : null}

      <TroisFaits preuve={preuve} />

      <Mention />

      <Suite preuve={preuve} />
    </div>
  )
}

/** La réponse, en une phrase. */
function Reponse({ preuve }: { preuve: PresenceProof }) {
  const qui = preuve.childName ?? 'Vous'
  const etaitLa = preuve.minutesAttended > 0

  /*
   * « Aïssatou était là. » — les deux derniers mots surlignés.
   *
   * Pour un compte qui suit pour lui-même, « Vous étiez là » : la charte
   * vouvoie tout le monde, et une phrase à la troisième personne sur son
   * propre écran se lit comme un dossier.
   */
  const verbe = preuve.childName == null ? 'étiez là.' : 'était là.'

  if (!etaitLa) {
    /*
     * Une absence : pas de surlignage.
     *
     * La charte est explicite — « en cas d'absence : pas de surlignage ». Le
     * signe dit « ce qui compte » ; l'employer sur une absence en ferait un
     * signe d'échec, et il perdrait son sens partout ailleurs.
     *
     * La phrase reste neutre, et la suite propose le rattrapage.
     */
    return (
      <h1 className="affiche">
        {preuve.childName == null
          ? 'Vous n’étiez pas en cours.'
          : `${qui} n’était pas en cours.`}
      </h1>
    )
  }

  return (
    <div className="stack stack--tight">
      <Affiche before={`${qui} `} accented={verbe} />
      {/*
        « Présent ! », une fois par écran.
        On ne connaît pas le genre de l'élève — l'application ne le demande
        nulle part, et c'est bien ainsi. Le mot reste donc au masculin, forme
        non marquée, plutôt que d'inventer une donnée pour accorder un
        adjectif.
      */}
      <p>
        <Annotation>Présent !</Annotation>
      </p>
    </div>
  )
}

/** Les minutes, et la ligne du temps qui dit quand. */
function Minutes({ preuve }: { preuve: PresenceProof }) {
  /*
   * L'heure d'arrivée convertie en minutes depuis le début.
   *
   * Elle décale le bloc surligné : un élève arrivé à la vingtième minute et
   * un élève parti vingt minutes avant la fin ont le même total, et ce n'est
   * pas la même séance. Sans `joinedAt`, le bloc part de zéro — faute de
   * mieux, et non parce qu'on suppose qu'il était là dès le début.
   */
  const debut = preuve.joinedAt
    ? Math.max(
        0,
        Math.round(
          (new Date(preuve.joinedAt).getTime() -
            new Date(preuve.startsAt).getTime()) /
            60_000,
        ),
      )
    : 0

  return (
    <Card>
      <div className="stack">
        {/*
          Le chiffre d'abord, puis l'unité.

          « 52 minutes sur 60 » se vérifie et se raconte le soir ; « taux
          d'assiduité 87 % » demande de croire un calcul. La charte en fait
          une règle, et c'est celle qui distingue cet écran d'un bulletin.
        */}
        <p className="row row--baseline">
          <span className="chiffre">{preuve.minutesAttended}</span>
          <strong>minutes sur {preuve.durationMinutes}</strong>
        </p>

        <LigneDuTemps
          minutesSuivies={preuve.minutesAttended}
          minutesTotales={preuve.durationMinutes}
          debutMinute={debut}
        />
      </div>
    </Card>
  )
}

/** Trois faits, pas plus. */
function TroisFaits({ preuve }: { preuve: PresenceProof }) {
  const faits: Array<{ icon: 'clock' | 'check' | 'file'; texte: string }> = []

  /*
   * L'heure d'arrivée, sans reproche.
   *
   * « Un retard se dit avec l'heure d'arrivée. » On écrit l'heure, et l'on
   * s'arrête là : ni « en retard », ni le nombre de minutes perdues au début.
   * Un parent sait lire une heure.
   */
  if (preuve.joinedAt) {
    faits.push({
      icon: 'clock',
      texte: `Arrivé à ${timeLabel(new Date(preuve.joinedAt))}`,
    })
  }

  /*
   * Les points de contrôle.
   *
   * Toutes les quinze minutes, le professeur demande si tout le monde suit.
   * Le nombre de réponses dit mieux que les minutes si l'élève était devant
   * son écran ou seulement connecté — c'est ce qui sépare une présence d'un
   * onglet ouvert.
   */
  if (preuve.checkpointsTotal > 0) {
    const r = preuve.checkpointsAnswered
    const t = preuve.checkpointsTotal
    faits.push({
      icon: 'check',
      texte:
        `${r} réponse${r > 1 ? 's' : ''} sur ` +
        `${t} point${t > 1 ? 's' : ''} de contrôle`,
    })
  }

  // Ce qui a été travaillé : le titre que le professeur a donné à son cours.
  const travaille = [preuve.title, preuve.subject, preuve.level]
    .filter((v): v is string => typeof v === 'string' && v !== '')
    .join(' · ')
  if (travaille !== '') faits.push({ icon: 'file', texte: travaille })

  if (faits.length === 0) return null

  return (
    <ul className="stack stack--tight liste-nue">
      {faits.map((fait) => (
        <li className="row" key={fait.texte}>
          <Tile icon={fait.icon} tone="neutral" size={18} />
          <span>{fait.texte}</span>
        </li>
      ))}
    </ul>
  )
}

/** La mention qui fait tenir tout le reste. */
function Mention() {
  return (
    <p className="row small muted">
      <Icon name="shield" size={18} />
      {/*
        « Compté par EduQuali, pas déclaré par l'élève. »

        La charte l'impose sur tout écran qui montre des minutes, et c'est la
        phrase qui rend le chiffre utile : la présence est comptée par le
        serveur de visioconférence, et un onglet fermé n'envoie pas de départ.
        Sans elle, « 52 minutes » ne vaut pas mieux qu'une case cochée par
        l'élève.

        Elle remplace « Présence certifiée », qui s'annonce au lieu de se
        prouver.
      */}
      <span>Compté par EduQuali, pas déclaré par l’élève.</span>
    </p>
  )
}

/** Un seul bouton. */
function Suite({ preuve }: { preuve: PresenceProof }) {
  const navigate = useNavigate()

  const manquees = Math.max(
    0,
    Math.min(preuve.durationMinutes, preuve.durationMinutes - preuve.minutesAttended),
  )
  // Cinq minutes : en dessous, c'est une entrée un peu tardive, et proposer
  // de rattraper trois minutes ferait d'un détail un problème.
  const aRattraper = manquees >= 5

  /*
   * Deux situations, un seul bouton dans chacune.
   *
   * S'il manque des minutes, le rattrapage passe devant : « une absence se
   * dit avec le moyen de la rattraper ». Sinon, c'est la séance suivante —
   * c'est le moment où le parent a confiance.
   *
   * Jamais les deux à la fois : un bouton principal par écran.
   */
  if (aRattraper && preuve.replay) {
    const prete = preuve.replay === 'READY'
    return (
      <div className="stack">
        <p>
          Les {manquees} minutes manquantes sont sur l’enregistrement.
        </p>
        <BigButton
          icon="play"
          disabled={!prete}
          onClick={() => navigate(`/direct/${preuve.sessionId}/rediffusion`)}
        >
          {prete ? 'Revoir la séance' : 'Enregistrement en préparation'}
        </BigButton>
      </div>
    )
  }

  return (
    <div className="stack">
      <BigButton icon="clock" onClick={() => navigate('/direct')}>
        Réserver la séance suivante
      </BigButton>
      {preuve.replay === 'READY' ? (
        // En second, et en bouton discret : revoir une séance qu'on a suivie
        // en entier est utile, mais ce n'est pas ce qui fait revenir.
        <Button
          variant="ghost"
          onClick={() => navigate(`/direct/${preuve.sessionId}/rediffusion`)}
        >
          Revoir la séance
        </Button>
      ) : null}
    </div>
  )
}
