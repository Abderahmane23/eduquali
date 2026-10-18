import { useState } from 'react'
import { OnboardingFlow } from './OnboardingFlow'
import {
  AUDIENCE_BY_ROLE,
  type Answers,
  type Audience,
  type Role,
} from './spec'

/**
 * Inscription complete : decouverte, choix du profil, puis parcours du profil.
 *
 *   intro.json ─ role_select ─┬→ teacher_onboarding.json
 *                             ├→ institution_onboarding.json
 *                             ├→ parent_onboarding.json
 *                             └→ student_onboarding.json
 *
 * Quatre, et non trois : le parcours parent manquait a cette liste alors que
 * `AUDIENCE_BY_ROLE` le sert depuis toujours. Un commentaire faux sur le
 * nombre de parcours est exactement ce qui a fait oublier `STUDENT` une
 * premiere fois.
 *
 * Deux parcours distincts plutot qu'un seul enorme fichier : les ecrans de
 * decouverte sont communs aux trois profils, et une question ajoutee cote
 * enseignant n'a pas a etre relue par un etablissement.
 *
 * Les reponses de l'intro sont transmises au second parcours : le profil
 * choisi reste dans `answers.role`, ce qui evite de le redemander et permet
 * a l'appelant de savoir quel type de compte creer.
 */
export function Signup({
  onDone,
  /** Profil impose par l'entree utilisee (lien « Publier une offre »). */
  presetRole,
}: {
  onDone: (role: Role, answers: Answers) => void | Promise<void>
  presetRole?: Role
}) {
  const [role, setRole] = useState<Role | undefined>(presetRole)
  const [introAnswers, setIntroAnswers] = useState<Answers>(
    presetRole ? { role: presetRole } : {},
  )

  if (!role) {
    return (
      <OnboardingFlow
        flow="intro"
        onDone={(answers) => {
          setIntroAnswers(answers)
          setRole(roleReel(answers))
        }}
      />
    )
  }

  const audience: Audience = AUDIENCE_BY_ROLE[role]

  return (
    <OnboardingFlow
      // Remonter le parcours remet le moteur a zero sur le nouveau fichier.
      key={audience}
      flow={audience}
      initialAnswers={introAnswers}
      // Revenir depuis le premier ecran du profil ramene au choix du profil,
      // au lieu de sortir de l'inscription sans prevenir.
      onBackOut={presetRole ? undefined : () => setRole(undefined)}
      onDone={(answers) => onDone(role, answers)}
    />
  )
}

/**
 * Le profil reel, derriere la carte choisie.
 *
 * --- Pourquoi une carte de moins que de profils ------------------------
 *
 * Le choix proposait « Parent d'eleve » et « Universitaire » cote a cote.
 * Deux cartes pour une meme famille : le parent d'un lyceen hesitait, et
 * l'eleve de terminale qui s'inscrit seul ne se reconnaissait dans aucune
 * des deux. Il n'y a plus qu'une carte, « Eleve ou etudiant », suivie
 * d'une question simple : « Etes-vous parent ? ».
 *
 * --- Pourquoi les roles de la base ne bougent pas ----------------------
 *
 * `PARENT` et `STUDENT` restent deux roles distincts dans Postgres. Ils
 * sont ecrits dans `profiles.role`, et surtout dans les politiques RLS :
 * un parent voit les seances de ses enfants, un etudiant majeur voit les
 * siennes. Les fondre en un seul role voudrait dire reecrire ces
 * politiques, et une erreur a cet endroit ouvre les donnees d'un enfant a
 * quelqu'un d'autre.
 *
 * `FAMILY` ne vit donc que le temps du choix. Il n'est jamais ecrit nulle
 * part : cette fonction le traduit avant que le parcours ne commence.
 */
export function roleReel(reponses: Answers): Role {
  const choisi = reponses.role
  if (choisi !== 'FAMILY') return choisi as Role
  return reponses.is_parent === 'yes' ? 'PARENT' : 'STUDENT'
}
