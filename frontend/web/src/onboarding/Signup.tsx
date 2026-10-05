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
          setRole(answers.role as Role)
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
