import { Link } from 'react-router-dom'

import { useSession } from '../app/session'

/**
 * Ce qu'un visiteur ne peut pas encore faire, et ou le faire.
 *
 * Un seul endroit decide de cette frontiere, parce qu'elle est un choix de
 * produit et non un detail d'ecran : **le web montre, l'application agit.**
 * On regarde chaque professeur, chaque etablissement, chaque offre sans
 * compte ; le compte n'est reclame qu'au premier geste qui engage une autre
 * personne — contacter, postuler, reserver.
 *
 * Le bouton n'est jamais masque, il est remplace. Une action absente se lit
 * comme « ce professeur ne prend personne », ce qui est faux et coute un
 * contact.
 */
export function AppGate({
  action,
}: {
  /** Le geste empeche, a l'infinitif : « contacter ce professeur ». */
  action: string
}) {
  const { session } = useSession()

  return (
    <div className="gate stack stack--tight">
      <strong className="gate__title">
        {session
          ? `Pour ${action}, ouvrez l’application`
          : `Pour ${action}, créez votre compte`}
      </strong>
      {/*
        Une ligne, et c'est tout.

        La porte portait trois niveaux de texte : le geste empeche, une
        phrase disant pourquoi il vit dans l'application, et un rappel que
        le compte marche des deux cotes. Trois explications pour une porte
        qu'on pousse — on la lit moins vite qu'on ne la franchit.

        Un visiteur garde ses deux boutons : ce ne sont pas des phrases,
        ce sont les deux seules choses a faire ici.
      */}
      {session ? null : (
        <div className="row" style={{ gap: 'var(--espace-2)' }}>
          <Link className="btn btn--primary" to="/inscription">
            Créer un compte
          </Link>
          <Link className="btn btn--ghost" to="/connexion">
            J’ai déjà un compte
          </Link>
        </div>
      )}
    </div>
  )
}
