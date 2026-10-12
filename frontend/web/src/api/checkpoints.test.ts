import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

/**
 * Les points de contrôle de module, et le résumé par l'IA.
 *
 * Quatre règles portent cette fonction. Trois se cassent en silence, et la
 * quatrième coûterait cher :
 *
 *   1. **anonyme pour la classe, nominatif pour le seul professeur.** Un élève
 *      qui croit que les autres verront sa réponse répond « oui », et le point
 *      de contrôle ne mesure plus rien ;
 *   2. **aucune donnée personnelle ne part chez Google.** L'invite porte une
 *      matière, un numéro de module et trois nombres ;
 *   3. **le résumé est une aide, pas une note.** Il n'entre dans aucun score ;
 *   4. **la clé Gemini ne quitte jamais le serveur**, et une clé préfixée
 *      `VITE_` est refusée plutôt que publiée dans un paquet.
 */
const code = (chemin: string) =>
  readFileSync(chemin, 'utf-8')
    .replace(/\r\n/g, '\n')
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^[ \t]*\/\/.*$/gm, '')

const brut = (chemin: string) =>
  readFileSync(chemin, 'utf-8').replace(/\r\n/g, '\n')

const worker = code('../../backend/api/[[...route]].ts')
const gemini = code('../../backend/api/_lib/gemini.ts')
const migration = brut('../../backend/supabase/migrations/0018_checkpoints.sql')
const salle = code('src/screens/Room.tsx')

const bloc = (depuis: string, jusqu: string) =>
  worker.slice(worker.indexOf(depuis), worker.indexOf(jusqu))

/**
 * Le corps d'une seule route, borné à la suivante.
 *
 * `worker.slice(indexOf(route))` prenait tout jusqu'à la FIN DU FICHIER : la
 * tranche grossissait à chaque route ajoutée en bas, et un `not.toContain`
 * finissait par échouer à cause de code sans aucun rapport — ici le `summary:`
 * d'un lot de la boutique, ajouté le 04/10.
 *
 * Un contrôle dont la portée dépend de la longueur du fichier n'éprouve pas ce
 * qu'il annonce. Celui-ci s'arrête au `app.` suivant.
 */
const route = (declaration: string) => {
  const debut = worker.indexOf(declaration)
  if (debut < 0) throw new Error(`route introuvable : ${declaration}`)
  const suivante = worker.indexOf('\napp.', debut + declaration.length)
  return worker.slice(debut, suivante < 0 ? undefined : suivante)
}

describe('anonyme pour la classe, nominatif pour le professeur', () => {
  it('un élève ne reçoit ni décompte ni résumé', () => {
    // « 11 sur 15 ont compris » apprendrait à l'élève qu'il est dans les quatre.
    // La réponse côté élève ne porte donc que son propre choix.
    const corps = route("app.get('/live/sessions/:id/checkpoints'")
    const cote = corps.slice(corps.indexOf("role: 'student'", 20))
    const objet = cote.slice(cote.indexOf('checkpoints: liste.map'))
    expect(objet).toContain('myAnswer')
    expect(objet).not.toContain('counts')
    expect(objet).not.toContain('summary')
  })

  it('le professeur reçoit les décomptes', () => {
    const corps = route("app.get('/live/sessions/:id/checkpoints'")
    const cote = corps.slice(
      corps.indexOf("role: 'teacher'"),
      corps.indexOf("role: 'student'"),
    )
    expect(cote).toContain('counts')
    expect(cote).toContain('summary')
  })

  it('l’écran le dit à l’élève, au lieu de le supposer', () => {
    // La garantie ne vaut que si elle est lue. Sans la phrase, l'élève suppose
    // le contraire — c'est l'hypothèse prudente, et elle fausse la réponse.
    expect(salle).toContain('Personne dans la classe ne voit votre réponse')
  })

  it('aucune politique ne laisse un élève lire la réponse d’un autre', () => {
    const politique = migration.slice(
      migration.indexOf('create policy "reponse : la sienne'),
      migration.indexOf('create policy "reponse : sa place'),
    )
    // Deux voies seulement : sa propre famille (`my_parent_id`) et le professeur
    // de la séance (`my_teacher_id`).
    expect(politique).toContain('my_parent_id()')
    expect(politique).toContain('my_teacher_id()')
    expect(politique).toContain('for select')
  })
})

describe('répondre une fois, et seulement pendant le vote', () => {
  it('la politique d’écriture exige une place payée et un vote ouvert', () => {
    const politique = migration.slice(
      migration.indexOf('create policy "reponse : sa place'),
    )
    expect(politique).toContain("e.status = 'CONFIRMED'")
    expect(politique).toContain('c.closed_at is null')
  })

  it('le serveur refuse un module déjà fermé', () => {
    // Répondre à un module terminé rendrait faux le résumé déjà lu par le
    // professeur.
    const route = bloc(
      "app.post('/live/checkpoints/:id/answer'",
      "app.post('/live/checkpoints/:id/close'",
    )
    expect(route).toContain('point.closed_at != null')
    expect(route).toContain('Ce module est termine')
  })

  it('une réponse ne se modifie ni ne se supprime', () => {
    // Pouvoir la changer après la fermeture réécrirait ce que le professeur a
    // déjà lu ; pouvoir la supprimer permettrait de recommencer le vote.
    const politiques = migration.match(/create policy[\s\S]*?;/g) ?? []
    const surReponses = politiques.filter((p) =>
      p.includes('on checkpoint_answers'),
    )
    expect(surReponses.length).toBeGreaterThan(0)
    for (const politique of surReponses) {
      expect(politique).not.toMatch(/for (update|delete|all)/)
    }
  })

  it('un double envoi ne fait pas échouer la réponse sous les yeux de l’élève', () => {
    // Un bouton tapoté deux fois sur un réseau lent est le cas normal, pas une
    // anomalie.
    const route = bloc(
      "app.post('/live/checkpoints/:id/answer'",
      "app.post('/live/checkpoints/:id/close'",
    )
    expect(route).toContain('.upsert(')
    expect(route).toContain("onConflict: 'checkpoint_id,enrolment_id'")
  })
})

describe('ouvrir et fermer', () => {
  it('ouvrir deux fois rend le même point de contrôle', () => {
    // Un second point sur le même module scinderait les réponses en deux
    // décomptes dont aucun ne serait vrai.
    const route = bloc(
      "app.post('/live/sessions/:id/checkpoints'",
      "app.post('/live/checkpoints/:id/answer'",
    )
    expect(route).toContain('reopened: true')
    expect(migration).toContain('unique (session_id, module_index)')
  })

  it('fermer deux fois ne rappelle pas Gemini', () => {
    // Un second appel paierait une deuxième fois pour la même phrase.
    const route = bloc(
      "app.post('/live/checkpoints/:id/close'",
      "app.get('/live/sessions/:id/checkpoints'",
    )
    expect(route).toContain('alreadyClosed: true')
    expect(route.indexOf('point.closed_at != null')).toBeLessThan(
      route.indexOf('summariseCheckpoint'),
    )
  })

  it('un échec de Gemini ne fait pas perdre le décompte', () => {
    // Le professeur a besoin des chiffres ; la phrase est un supplément, et
    // perdre les deux pour un incident chez Google serait absurde.
    const route = bloc(
      "app.post('/live/checkpoints/:id/close'",
      "app.get('/live/sessions/:id/checkpoints'",
    )
    expect(route).toContain('catch')
    expect(route).toContain('counts: decompte')
  })

  it('l’ouverture est annoncée dans la salle, pas attendue par sondage', () => {
    // La fenêtre de réponse se compte en dizaines de secondes : quinze secondes
    // de latence la manqueraient.
    expect(salle).toContain("type: 'checkpoint'")
    expect(salle).toContain('publishData')
    // Et un sondage de rattrapage existe quand même, pour l'élève entré après
    // l'ouverture.
    expect(salle).toContain('api.checkpoints(id)')
    expect(salle).toContain('20_000')
  })
})

describe('ce qui part chez Google', () => {
  it('l’invite ne porte ni nom, ni identifiant, ni texte d’élève', () => {
    /*
     * L'ancre de fin a changé le 11/10 : `generate` rend désormais les jetons
     * consommés en plus du texte, donc l'appel s'écrit
     * `(await this.generate(...)).text`. Un `indexOf` qui ne trouve plus rien
     * rend -1, et `slice` rendait alors la chaîne vide — le test passait
     * encore en vérifiant qu'une chaîne vide ne contient aucun nom interdit.
     *
     * C'est exactement le piège que ce projet rencontre partout : une
     * vérification qui s'éteint sans rien dire. L'ancre est donc vérifiée
     * avant d'être utilisée.
     */
    const debut = gemini.indexOf('const invite = [')
    const fin = gemini.indexOf('this.generate(MODELS.chat', debut)
    expect(debut, 'l’invite du résumé est introuvable').toBeGreaterThan(-1)
    expect(fin, 'l’appel au modèle est introuvable').toBeGreaterThan(debut)
    const invite = gemini.slice(debut, fin)
    expect(invite.length, 'tranche vide : le test ne vérifierait rien').toBeGreaterThan(50)
    // Ce qui entre : matière, classe, module, trois nombres.
    expect(invite).toContain('input.subject')
    expect(invite).toContain('input.yes')
    // Ce qui n'entre pas.
    for (const interdit of [
      'childName',
      'firstName',
      'enrolment',
      'userId',
      'phone',
      'identity',
    ]) {
      expect(invite).not.toContain(interdit)
    }
  })

  it('les consignes de l’assistant ne nomment personne', () => {
    /*
     * L'assistant ouvert le 11/10 met la règle à l'épreuve : la question de
     * l'élève part forcément chez Google. Ce qui reste tenu, et que ce test
     * vérifie : les consignes système décrivent un **rôle**, pas une
     * personne. Google ne peut donc pas relier deux conversations au même
     * enfant.
     */
    const routes = readFileSync(
      '../../backend/api/[[...route]].ts',
      'utf-8',
    )
    const debut = routes.indexOf('const CONSIGNES: Record<string, string> = {')
    expect(debut, 'les consignes sont introuvables').toBeGreaterThan(-1)
    const consignes = routes.slice(debut, routes.indexOf('\n}', debut))
    expect(consignes.length).toBeGreaterThan(100)

    for (const interdit of [
      'firstName',
      'first_name',
      'childName',
      'displayName',
      'userId',
      'phone',
      'city',
      'teacherId',
    ]) {
      expect(
        consignes,
        `les consignes interpolent ${interdit}`,
      ).not.toContain(interdit)
    }

    // Et l'historique envoyé ne porte que des tours de parole : deux champs,
    // pas de place pour un nom.
    const tour = gemini.slice(
      gemini.indexOf('export interface GeminiTurn {'),
      gemini.indexOf('}', gemini.indexOf('export interface GeminiTurn {')),
    )
    expect(tour).toContain('role:')
    expect(tour).toContain('body: string')
    expect(tour).not.toContain('name')
  })

  it('la signature de l’appel ne peut pas transporter un nom', () => {
    // La garantie tient dans le type : il n'y a pas de champ où mettre un nom.
    const signature = gemini.slice(
      gemini.indexOf('async summariseCheckpoint(input: {'),
      gemini.indexOf('}): Promise<string> {', gemini.indexOf('summariseCheckpoint')),
    )
    expect(signature).toContain('subject: string')
    expect(signature).toContain('yes: number')
    expect(signature).not.toContain('name')
    expect(signature).not.toContain('student')
  })

  it('zéro réponse n’appelle pas Gemini du tout', () => {
    // Une invite sur un décompte vide produirait une phrase inventée.
    expect(gemini).toContain('Aucune reponse a resumer')
    const route = bloc(
      "app.post('/live/checkpoints/:id/close'",
      "app.get('/live/sessions/:id/checkpoints'",
    )
    expect(route).toContain('decompte.yes + decompte.partly + decompte.no > 0')
  })
})

describe('la clé Gemini', () => {
  it('est refusée si elle porte le préfixe VITE_', () => {
    // Vite recopierait une telle clé dans le paquet du site, donc dans le
    // navigateur de chaque visiteur.
    expect(gemini).toContain("startsWith('VITE_')")
  })

  it('ne vient que de l’environnement du serveur', () => {
    expect(worker).toContain('process.env.GEMINI_API_KEY')
    // Et nulle part dans le site : un seul emploi suffirait à la publier.
    for (const fichier of [
      'src/api/supabase.ts',
      'src/api/client.ts',
      'src/screens/Room.tsx',
    ]) {
      expect(code(fichier)).not.toContain('GEMINI')
    }
  })

  it('le site ne connaît même pas le nom du modèle', () => {
    // Le choix du modèle est une décision de coût côté serveur. L'écrire dans le
    // client en ferait une deuxième source, qui divergerait.
    for (const fichier of ['src/screens/Room.tsx', 'src/api/client.ts']) {
      expect(code(fichier)).not.toContain('gemini-')
    }
  })
})

describe('le résumé est une aide, pas une note', () => {
  it('le schéma le dit, là où quelqu’un voudra s’en servir', () => {
    expect(migration).toContain('aide, pas une note')
  })

  it('il n’entre dans aucun score', () => {
    // `trustScore` et `scoreTest` sont les deux calculs notés du dépôt. Ni l'un
    // ni l'autre ne doit lire un résumé.
    const domaine = code('../../backend/api/_lib/domain.ts')
    expect(domaine).not.toContain('summary')
    expect(domaine).not.toContain('checkpoint')
  })

  it('aucun élève ne le lit', () => {
    // Borné à la route, pas à la fin du fichier : voir `route()` plus haut.
    const corps = route("app.get('/live/sessions/:id/checkpoints'")
    const cote = corps.slice(corps.indexOf("role: 'student'"))
    expect(cote).not.toContain('summary')
  })
})

describe('les repères de modules dans la rediffusion', () => {
  // Les bornes suivent l'ordre reel du fichier : `/live/presence` precede
  // desormais `/replay`, et prendre l'ancienne borne rendait une tranche vide —
  // tous les controles passaient alors sur une chaine vide, ce qui est
  // exactement le test qui mente.
  const route = worker.slice(
    worker.indexOf("app.get('/live/sessions/:id/replay'"),
    // Borne a la route suivante et non plus loin : `/videos/:itemId/url` se
    // trouve entre les deux et lit `course_items` a bon droit — l'inclure faisait
    // echouer un controle qui visait la rediffusion.
    worker.indexOf("app.get('/videos/:itemId/url'"),
  )

  it('ne découpe pas la vidéo', () => {
    // Le plan prévoyait quatre segments et autant de `course_items`. Découper
    // demanderait un ré-encodage, doublerait le stockage facturé chez Cloudflare
    // multiplierait par quatre les URL signées à tenir — pour répondre à une
    // question que `?t=` règle.
    expect(route).toContain('startSeconds')
    expect(route).not.toContain('course_items')
    expect(route).not.toContain('fetchFromUrl')
  })

  it('part de l’ouverture de la salle, qui est le zéro de l’enregistrement', () => {
    expect(route).toContain('seance.opened_at')
    expect(route).toContain('session_checkpoints')
  })

  it('n’invente aucun repère quand il n’y a pas de point de contrôle', () => {
    // Couper à 0, 22, 45 et 67 minutes au hasard serait pire que de ne pas
    // couper : l'élève atterrirait au milieu d'une phrase en croyant être au
    // début d'un module.
    expect(route).toContain('if (ouverture != null)')
    expect(route).toContain('chapters: chapitres')
  })

  it('recule de quelques secondes sur chaque bascule', () => {
    // L'egress démarre une seconde ou deux après l'ouverture de la salle, et
    // atterrir après la première phrase d'un module fait croire qu'on a manqué
    // quelque chose.
    expect(route).toContain('fin - 5')
  })

  it('les deux clients proposent les modules', () => {
    const site = code('src/screens/Replay.tsx')
    expect(site).toContain('Reprendre à')
    expect(site).toContain('t=${depart}')
    // `key` sur le départ : changer `src` seul ne recharge pas toujours un
    // `iframe`.
    expect(site).toContain('key={depart}')

    const mobile = code(
      '../mobile/lib/presentation/screens/live/session_replay_page.dart',
    )
    expect(mobile).toContain('Reprendre à')
    expect(mobile).toContain('seekTo(chapitre.start)')
  })
})
