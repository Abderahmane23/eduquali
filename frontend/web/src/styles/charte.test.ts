import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

/**
 * La charte EduQuali, vérifiée contre sa source.
 *
 * --- Pourquoi ces tests existent ----------------------------------------
 *
 * La charte est un fichier, `design/charte/tokens.json`, et la feuille de
 * style en est une transcription. Deux copies d'une même palette divergent à
 * la première retouche, et le symptôme est un site qui *ressemble* à la
 * marque sans en être — c'est précisément ce que « Fondements » reproche à
 * l'état précédent : trois bleus différents, un dans le logo, un à la
 * connexion, un sur le profil.
 *
 * Ces tests comparent donc valeur par valeur, et tiennent les quatre règles
 * que la charte énonce comme des interdits. Un interdit ne lève aucune
 * erreur quand on l'enfreint : il s'affiche.
 */
const tokens = readFileSync('src/styles/tokens.css', 'utf-8')
const charte = JSON.parse(
  readFileSync('../../design/charte/tokens.json', 'utf-8'),
) as {
  name: string
  color: {
    themes: { id: string; name: string }[]
    tokens: { name: string; value: Record<string, string>; usage: string }[]
  }
  type: {
    fonts: { family: string; file: string; weight: string }[]
    families: Record<string, string>
    groups: { name: string; styles: { name: string; fontSize: string }[] }[]
  }
  spacing: { tokens: { name: string; value: string }[] }
  radius: { tokens: { name: string; value: string }[] }
  trait: { tokens: { name: string; value: string }[] }
}

/** La feuille sans ses commentaires : la prose n'est pas une déclaration. */
const regles = tokens.replace(/\/\*[\s\S]*?\*\//g, '')

/** Les déclarations d'un bloc, par son sélecteur. */
function bloc(selecteur: string): Map<string, string> {
  const i = regles.indexOf(selecteur)
  expect(i, `${selecteur} introuvable`).toBeGreaterThan(-1)
  const debut = regles.indexOf('{', i) + 1
  let profondeur = 1
  let j = debut
  while (j < regles.length && profondeur > 0) {
    if (regles[j] === '{') profondeur++
    else if (regles[j] === '}') profondeur--
    j++
  }
  const corps = regles.slice(debut, j)
  return new Map(
    [...corps.matchAll(/(--[a-z0-9-]+):\s*([^;]+);/g)].map((m) => [
      m[1],
      m[2].trim().toLowerCase(),
    ]),
  )
}

const cahier = bloc(':root {')
const tableauAuto = bloc(":root:not([data-theme='cahier'])")
const tableauChoisi = bloc(":root[data-theme='tableau']")

describe('la palette est celle de la charte, valeur par valeur', () => {
  it('les deux thèmes de la charte existent', () => {
    expect(charte.color.themes.map((t) => t.id)).toEqual(['cahier', 'tableau'])
  })

  for (const jeton of JSON.parse(
    readFileSync('../../design/charte/tokens.json', 'utf-8'),
  ).color.tokens as {
    name: string
    value: Record<string, string>
  }[]) {
    it(`\`${jeton.name}\` vaut ${jeton.value.cahier} en Cahier`, () => {
      expect(
        cahier.get(`--${jeton.name}`),
        `--${jeton.name} absent du thème Cahier`,
      ).toBe(jeton.value.cahier.toLowerCase())
    })
  }

  it('le thème Tableau redéfinit tout ce qui change, et rien d’autre', () => {
    /*
     * Quatre familles ne changent PAS avec le thème, et c'est leur
     * définition : les couleurs `marque-*` (logo, affiches, supports
     * imprimés), le `surligneur` et le `bon-point`. Un surligneur reste un
     * surligneur sur un tableau noir.
     */
    for (const jeton of charte.color.tokens) {
      const nom = `--${jeton.name}`
      const changeDansLaCharte =
        jeton.value.cahier.toLowerCase() !== jeton.value.tableau.toLowerCase()
      const redefini = tableauAuto.has(nom)

      if (changeDansLaCharte) {
        expect(
          redefini,
          `${nom} garde sa valeur Cahier sur le thème Tableau`,
        ).toBe(true)
        expect(tableauAuto.get(nom)).toBe(jeton.value.tableau.toLowerCase())
      } else {
        expect(
          redefini,
          `${nom} ne change pas dans la charte : le redéfinir le ferait dériver`,
        ).toBe(false)
      }
    }
  })

  it('le choix manuel dit exactement la même chose que le réglage système', () => {
    /*
     * Les deux blocs sont dupliqués, et c'est volontaire :
     * `:root:not([data-theme='cahier'])` ne vaut que dans la requête média,
     * et un sélecteur groupé invalide ferait tomber le bloc entier chez un
     * navigateur qui ne comprend pas l'un des deux. Le prix d'une
     * duplication est qu'elle dérive ; ce test est ce qui l'empêche.
     */
    for (const [nom, valeur] of tableauAuto) {
      expect(
        tableauChoisi.get(nom),
        `${nom} vaut « ${valeur} » au réglage système et « ${tableauChoisi.get(nom)} » au choix manuel`,
      ).toBe(valeur)
    }
    expect(tableauChoisi.size).toBe(tableauAuto.size)
  })

  it('aucun jeton n’est déclaré deux fois', () => {
    // `--measure` l'avait été — 68ch puis 62ch. Seule la seconde agissait, et
    // la première se lisait comme la règle en vigueur.
    const vus = new Map<string, number>()
    const i = regles.indexOf(':root {')
    const corps = regles.slice(i, regles.indexOf('\n}', i))
    for (const m of corps.matchAll(/^\s*(--[a-z0-9-]+):/gm)) {
      vus.set(m[1], (vus.get(m[1]) ?? 0) + 1)
    }
    expect([...vus].filter(([, n]) => n > 1).map(([nom]) => nom)).toEqual([])
  })
})

describe('aucune couleur hors de la palette', () => {
  /*
   * Le cinquième interdit, implicite mais réel.
   *
   * La feuille d'application portait trois surfaces vidéo en `#0b0b10` et un
   * fond d'illustration en `#f2f6fd` — quatre couleurs sans jeton, sans nom,
   * introuvables dans la charte. Une couleur écrite en dur se recopie,
   * dérive, et finit à trois valeurs voisines : c'est exactement ce que
   * « Fondements » reproche à l'état d'avant, trois bleus différents selon
   * l'écran.
   *
   * Le blanc et le noir purs restent admis : ils servent de base aux jetons
   * eux-mêmes.
   */
  const brut = readFileSync('src/styles/app.css', 'utf-8')
  const sansCommentaires = brut.replace(/\/\*[\s\S]*?\*\//g, '')

  it('la feuille d’application n’écrit aucune couleur de la palette', () => {
    /*
     * La règle, et pourquoi elle est formulée ainsi.
     *
     * Une première version vérifiait que chaque hexadécimal se retrouvait
     * dans `tokens.css`. Elle laissait passer `#0b0b10` écrit en dur dès
     * lors qu'un jeton portait la même valeur — donc exactement le défaut
     * qu'elle devait attraper.
     *
     * Une seconde interdisait tout hexadécimal, avec une exception pour
     * `mask-image`. L'exception demandait de regarder en arrière dans le
     * texte, ce qui est fragile : une accolade de plus et elle cesse de
     * reconnaître le cas.
     *
     * Celle-ci est plus simple et attrape les deux défauts réels :
     * `app.css` n'écrit **que** du noir et du blanc purs — les bornes d'un
     * masque de défilement, qui ne sont pas des couleurs mais des opacités.
     * Toute autre valeur appartient à la palette et se nomme.
     */
    // `Array.from` plutot qu'un etalement de `Set` sur plusieurs lignes.
    //
    // La meme expression, ecrite en etalant un `Set` sur plusieurs lignes,
    // rendait un tableau vide la ou sa version sur une seule ligne rendait
    // la bonne reponse. Le test passait donc en ne verifiant rien — ce qui
    // est pire que pas de test du tout. `Array.from` ne pose pas la
    // question, et le passage ci-dessous est verifie en cassant la regle
    // avant de la livrer.
    const toutes = Array.from(
      new Set(
        Array.from(
          sansCommentaires.matchAll(/#[0-9a-fA-F]{3,8}/g),
          (m) => m[0].toLowerCase(),
        ),
      ),
    )
    const neutres = ['#000', '#fff', '#000000', '#ffffff']
    const fautives = toutes.filter((c) => !neutres.includes(c))

    expect(
      fautives,
      `couleurs écrites en dur : ${fautives.join(', ')}`,
    ).toEqual([])
  })
})

describe('les quatre interdits de la charte', () => {
  const app = readFileSync('src/styles/app.css', 'utf-8')
  const feuilles = (tokens + '\n' + app).replace(/\/\*[\s\S]*?\*\//g, '')

  it('pas d’ombre', () => {
    /*
     * « Pas d'ombre, pas de dégradé, pas de carte à bord coloré. » Le relief
     * vient du contour : `trait-fin` en `ligne`, `trait-fort` en `encre`. Un
     * trait se voit en plein soleil, là où une ombre de 12 px disparaît —
     * précisément la condition dans laquelle ce produit sert.
     */
    const ombres = [...feuilles.matchAll(/box-shadow:\s*([^;]+);/g)]
      .map((m) => m[1].trim())
      .filter((v) => v !== 'none' && !v.startsWith('inset'))
    expect(ombres, 'des ombres sont revenues').toEqual([])
  })

  it('pas de dégradé de couleur', () => {
    /*
     * Un `mask-image` en est exempté, et ce n'est pas une échappatoire : un
     * masque n'ajoute aucune couleur, il rend transparent. Celui de la
     * rangée d'onglets sert à dire qu'elle défile, en estompant ses deux
     * bords dans la couleur de la barre — sans quoi un libellé tranché net
     * au bord de l'écran se lit comme un défaut d'affichage.
     *
     * Ce que la charte refuse est le dégradé de fond : « le décor par défaut
     * de milliers d'applications ».
     */
    const degrades = [...feuilles.matchAll(/(linear|radial|conic)-gradient\(/g)]
      .filter((m) => {
        const avant = feuilles.slice(Math.max(0, m.index! - 80), m.index!)
        return !/mask-image:\s*$/.test(avant)
      })
      .map((m) => feuilles.slice(Math.max(0, m.index! - 40), m.index! + 20).trim())
    expect(degrades, 'un dégradé de fond est revenu').toEqual([])
  })

  it('le surligneur n’est jamais un bouton ni du texte', () => {
    /*
     * « Jamais un bouton. Jamais du texte. » C'est ce qui garde au signe sa
     * valeur : s'il devient une couleur de bouton, il cesse de dire « voici
     * ce qui compte » et dit « appuyez ici ».
     *
     * Le seul texte autorisé sur du surligneur est `sur-surligneur`, et il
     * est posé par la règle `.surlignage`, jamais à la main.
     */
    const fautifs: string[] = []
    for (const m of feuilles.matchAll(/color:\s*var\(--surligneur\)/g)) {
      const autour = feuilles.slice(Math.max(0, m.index! - 120), m.index!)
      // `background-color` et `border-color` finissent par `color:` eux
      // aussi : on ne retient que la couleur de texte.
      if (!/(background|border|outline|caret|text-decoration)-$/.test(autour)) {
        fautifs.push(autour.slice(-60).trim())
      }
    }
    expect(fautifs, 'du texte en surligneur').toEqual([])

    const i = feuilles.indexOf('.btn--primary')
    expect(
      feuilles.slice(i, feuilles.indexOf('}', i)),
      'un bouton en surligneur',
    ).not.toContain('--surligneur')
  })

  it('pas d’orange : il reste au bouton Orange Money', () => {
    // Orange Money possède cette couleur dans l'esprit d'un utilisateur
    // guinéen. L'employer ailleurs ferait croire à un paiement.
    const noms = [...cahier.keys()]
    expect(noms.filter((n) => n.includes('orange'))).toEqual([])
  })
})

describe('les trois polices', () => {
  it('sont embarquées, pas chargées depuis Google', () => {
    /*
     * L'application se transmet d'un téléphone à l'autre et doit s'afficher
     * sans réseau. Le site suit la même règle : 140 Ko de fontes servies
     * depuis le même domaine valent mieux qu'une requête vers un tiers que la
     * connexion peut ne jamais rendre.
     */
    expect(tokens).not.toContain('fonts.googleapis')
    expect(tokens).not.toContain('fonts.gstatic')

    const faces = [...tokens.matchAll(/@font-face\s*\{[^}]*\}/g)].map((m) => m[0])
    expect(faces.length, 'il manque des fontes').toBe(charte.type.fonts.length)
    for (const face of faces) {
      expect(face, 'une fonte servie depuis ailleurs').toContain('/polices/')
      // Sans `swap`, la page reste blanche le temps du téléchargement.
      expect(face).toContain('font-display: swap')
    }
  })

  it('portent les noms de la charte', () => {
    for (const famille of Object.values(charte.type.families)) {
      expect(tokens, `la famille ${famille} manque`).toContain(famille)
    }
  })

  it('les fichiers sont là', () => {
    for (const fonte of charte.type.fonts) {
      const nom = fonte.file.split('/').pop()!
      expect(
        () => readFileSync(`public/polices/${nom}`),
        `public/polices/${nom} manque`,
      ).not.toThrow()
    }
  })
})

describe('les tailles de texte', () => {
  it('le texte courant n’est jamais sous 16 px, le secondaire sous 14', () => {
    // La règle de la charte, et la raison d'être de Lexend : des lettres
    // larges et bien espacées ne servent à rien à 12 px.
    expect(cahier.get('--t-corps')).toBe('1rem')
    expect(cahier.get('--t-secondaire')).toBe('0.875rem')
  })

  it('`etiquette` est le seul style sous 14 px', () => {
    /*
     * 12 px, en capitales, quatre mots au plus : un sur-titre, pas du texte.
     * C'est pourquoi tous les anciens `--t-micro` de 13 px ont été remontés à
     * `--t-secondaire` plutôt que ramenés à `etiquette`.
     */
    const sousQuatorze = [...cahier]
      .filter(([nom]) => nom.startsWith('--t-'))
      .filter(([, v]) => {
        const rem = Number(v.replace('rem', ''))
        return v.endsWith('rem') && rem < 0.875
      })
      .map(([nom]) => nom)
    expect(sousQuatorze).toEqual(['--t-etiquette'])
  })
})

describe('les formes', () => {
  it('les cinq rayons de la charte', () => {
    for (const rayon of charte.radius.tokens) {
      expect(cahier.get(`--${rayon.name}`), `--${rayon.name}`).toBe(
        rayon.value.toLowerCase(),
      )
    }
  })

  it('les deux épaisseurs de trait', () => {
    for (const trait of charte.trait.tokens) {
      expect(cahier.get(`--${trait.name}`), `--${trait.name}`).toBe(
        trait.value.toLowerCase(),
      )
    }
  })

  it('les sept espaces, et les deux cibles tactiles', () => {
    for (const espace of charte.spacing.tokens) {
      expect(cahier.get(`--${espace.name}`), `--${espace.name}`).toBe(
        espace.value.toLowerCase(),
      )
    }
    // 48 px plutôt que les 44 du critère WCAG : c'est le choix de la charte,
    // et il ne se perd pas dans un arrondi.
    expect(cahier.get('--cible')).toBe('48px')
    expect(cahier.get('--cible-principale')).toBe('56px')
  })
})
