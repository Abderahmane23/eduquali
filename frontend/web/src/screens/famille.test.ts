import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

/**
 * Les écrans d'une famille, et les règles qu'ils ne doivent pas enfreindre.
 *
 * --- Pourquoi des tests sur du texte ------------------------------------
 *
 * Ces règles sont des interdits de la charte, et un interdit ne lève aucune
 * erreur quand on l'enfreint : il s'affiche. « 87 % d'assiduité » compile
 * aussi bien que « 52 minutes sur 60 » ; un surlignage sur une absence est du
 * JSX valide. Rien ne les attrape, sauf une lecture.
 *
 * Ils lisent donc le source des deux écrans. C'est grossier, et c'est le
 * seul endroit où la règle est vérifiable sans monter un rendu complet pour
 * chacun des cas.
 */
const presence = readFileSync('src/screens/Presence.tsx', 'utf-8')
const famille = readFileSync('src/screens/Famille.tsx', 'utf-8')

/** Le source sans ses commentaires : la prose explique les règles, elle ne
 *  les enfreint pas. Sans ce nettoyage, chaque test échouerait sur le
 *  commentaire qui dit pourquoi il existe. */
function code(source: string): string {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '')
}

const codePresence = code(presence)
const codeFamille = code(famille)

/**
 * Le corps d'un bloc, accolades comptées.
 *
 * Découper « de ce mot jusqu'au prochain `return` » paraissait suffire, et
 * sautait en fait par-dessus le `return` de la branche elle-même pour
 * englober la fonction suivante : le test lisait alors du code qu'il n'avait
 * pas à juger, et échouait sur un `<Affiche>` parfaitement légitime.
 */
function bloc(source: string, debut: string): string {
  const i = source.indexOf(debut)
  expect(i, `${debut} introuvable`).toBeGreaterThan(-1)
  const ouvrante = source.indexOf('{', i)
  let profondeur = 1
  let j = ouvrante + 1
  while (j < source.length && profondeur > 0) {
    if (source[j] === '{') profondeur++
    else if (source[j] === '}') profondeur--
    j++
  }
  return source.slice(ouvrante, j)
}

describe('le garde-fou se tient lui-même', () => {
  it('le nettoyage ne vide pas les fichiers', () => {
    /*
     * Un test qui cherche une absence dans une chaîne vide passe toujours.
     * Les trois quarts de ce fichier vérifient qu'un mot n'apparaît pas :
     * si `code()` rendait du vide, ils passeraient tous sans rien tenir.
     */
    expect(codePresence.length).toBeGreaterThan(2000)
    expect(codeFamille.length).toBeGreaterThan(3000)
    expect(codePresence).toContain('minutesAttended')
    expect(codeFamille).toContain('LigneDuTemps')
  })
})

describe('le chiffre est des minutes, jamais un taux', () => {
  /*
   * « 52 minutes sur 60 » se vérifie et se raconte le soir ; « taux
   * d'assiduité 87 % » demande de croire un calcul. C'est ce qui distingue
   * cet écran d'un bulletin, et c'est la première chose qu'un développeur
   * pressé remplacerait par un pourcentage — c'est plus court à écrire.
   */
  it('aucun pourcentage d’assiduité n’est calculé', () => {
    for (const [nom, source] of [
      ['Presence', codePresence],
      ['Famille', codeFamille],
    ] as const) {
      expect(source, `${nom} : un taux a remplacé les minutes`).not.toMatch(
        /assiduit|taux de pr|% de pr/i,
      )
    }
  })

  it('les minutes sont écrites « sur » la durée, pas seules', () => {
    // Un total sans son dénominateur ne se vérifie pas : « 52 minutes »
    // n'apprend rien sans « sur 60 ».
    expect(codePresence).toContain('minutes sur {preuve.durationMinutes}')
    expect(codeFamille).toContain('minutes sur {seance.durationMinutes}')
  })
})

describe('la mention qui rend le chiffre utile', () => {
  it('« Compté par EduQuali, pas déclaré par l’élève. »', () => {
    /*
     * La charte l'impose sur tout écran qui montre des minutes. Sans elle,
     * « 52 minutes » ne vaut pas mieux qu'une case cochée par l'élève — et
     * c'est toute la différence entre EduQuali et un cahier de présence.
     */
    expect(presence).toContain(
      'Compté par EduQuali, pas déclaré par l’élève.',
    )
  })

  it('et jamais « présence certifiée », qui s’annonce au lieu de prouver', () => {
    expect(codePresence).not.toMatch(/certifi/i)
  })
})

describe('ni note, ni classement, ni comparaison', () => {
  /*
   * EduQuali promet ce qu'il mesure — un professeur présent, quinze places,
   * des minutes comptées — et rien d'autre. Une note sur cet écran ferait
   * promettre un résultat scolaire que rien dans le produit ne produit.
   */
  const interdits = [
    /\bnote\b/i,
    /\bclassement\b/i,
    /\bmoyenne\b/i,
    /\brang\b/i,
    /meilleur[es]? élève/i,
  ]

  for (const motif of interdits) {
    it(`${motif} n’apparaît sur aucun des deux écrans`, () => {
      expect(codePresence).not.toMatch(motif)
      expect(codeFamille).not.toMatch(motif)
    })
  }
})

describe('le surligneur ne marque jamais une absence', () => {
  it('l’absence est rendue sans `Affiche`', () => {
    /*
     * « En cas d'absence : pas de surlignage. » Le signe dit « ce qui
     * compte » ; l'employer sur une absence en ferait un signe d'échec, et il
     * perdrait son sens partout ailleurs.
     *
     * On lit la branche qui traite l'absence, et on vérifie qu'elle rend un
     * titre nu.
     */
    const branche = bloc(codePresence, 'if (!etaitLa)')
    expect(branche).not.toContain('<Affiche')
    expect(branche).not.toContain('<Surlignage')
    expect(branche).toContain('className="affiche"')
  })

  it('et le retard se dit avec l’heure d’arrivée, sans le commenter', () => {
    // « Un retard se dit avec l'heure d'arrivée. » On écrit l'heure, et l'on
    // s'arrête là.
    expect(codePresence).toContain('Arrivé à ')
    expect(codePresence).not.toMatch(/en retard|minutes perdues/i)
  })
})

describe('un seul bouton principal par écran', () => {
  it('rattraper ou réserver, jamais les deux en bouton plein', () => {
    /*
     * S'il manque des minutes, le rattrapage passe devant — « une absence se
     * dit avec le moyen de la rattraper ». Sinon c'est la séance suivante.
     * Deux `BigButton` côte à côte feraient deux actions principales, et
     * l'écran cesserait de dire quoi faire.
     */
    const suite = codePresence.slice(codePresence.indexOf('function Suite'))
    expect(suite.split('<BigButton').length - 1).toBe(2)
    // Les deux sont dans deux `return` exclusifs, pas dans le même bloc.
    expect(suite.split('return (').length - 1).toBe(2)
  })
})

describe('la ligne du temps n’apparaît qu’avec des minutes', () => {
  it('l’accueil la garde derrière une condition', () => {
    /*
     * Une ligne du temps vide ne montre pas « zéro minute suivie » : elle
     * montre un composant en panne. C'est la famille des défauts qui coûtent
     * cher ici — ils ressemblent à un état normal.
     */
    expect(codeFamille).toContain('derniere.minutesAttended != null')
    expect(codeFamille).toContain('!aVenir && suivies != null')
  })

  it('et l’écran sans séance ne la rend pas du tout', () => {
    const vide = bloc(codeFamille, 'if (seances.length === 0)')
    expect(vide.length).toBeGreaterThan(100)
    expect(vide).not.toContain('<LigneDuTemps')
  })
})

describe('une place est prise pour quelqu’un', () => {
  /*
   * `POST /live/enrol` accepte un `childId` depuis le premier jour, et le
   * site ne l'envoyait jamais : toute place prise ici partait avec
   * `child_id = null`.
   *
   * Le defaut ne levait rien. Il se lisait trois ecrans plus loin, sur la
   * preuve de presence, en « Vous etiez la » au lieu du prenom — et un
   * parent de deux enfants ne pouvait pas reserver deux places sur la meme
   * seance, le serveur rendant la premiere comme « deja inscrit ».
   */
  const live = readFileSync('src/screens/Live.tsx', 'utf-8')

  it('la réservation transmet l’enfant choisi', () => {
    expect(code(live)).toContain('childId: liste[pourQui]?.id')
  })

  it('et le choix n’est posé qu’à partir de deux enfants', () => {
    // Avec un seul enfant la question est deja repondue ; la poser ajouterait
    // un geste a chaque reservation pour ne rien decider.
    expect(code(live)).toContain('liste.length > 1')
  })

  it('les enfants viennent du serveur, pas d’une saisie libre', () => {
    // Un champ « prénom de l'enfant » laisserait ecrire n'importe quoi, et le
    // serveur refuserait un `childId` inconnu — une erreur a la validation du
    // paiement, au pire moment.
    expect(code(live)).toContain('api.children()')
  })
})
