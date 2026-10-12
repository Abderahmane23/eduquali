import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

/**
 * Le thème, et son mode sombre.
 *
 * --- Le défaut que ces tests empêchent de revenir -----------------------
 *
 * Le mode sombre redéfinissait `--c-accent` en violet `#9D86FF` — un reste de
 * l'époque où l'application était violette, avant l'alignement du 24/09 — et
 * ne redéfinissait **ni** le dégradé d'en-tête, **ni** la couleur de mise en
 * avant, **ni** la bande de section. Une page sombre affichait donc un haut
 * bleu, des boutons violets, et une marque que la page claire ne montre
 * nulle part.
 *
 * Ce genre de défaut ne lève aucune erreur : il s'affiche. Et il ne s'affiche
 * que chez les visiteurs dont le système est en sombre — c'est-à-dire pas
 * chez celui qui développe. D'où ces tests.
 */
const tokens = readFileSync('src/styles/tokens.css', 'utf-8')

/** Les trois blocs de déclarations : clair, système sombre, sombre choisi. */
function bloc(selecteur: string): string {
  const i = tokens.indexOf(selecteur)
  expect(i, `${selecteur} introuvable`).toBeGreaterThan(-1)
  const debut = tokens.indexOf('{', i) + 1
  let profondeur = 1
  let j = debut
  while (j < tokens.length && profondeur > 0) {
    if (tokens[j] === '{') profondeur++
    else if (tokens[j] === '}') profondeur--
    j++
  }
  return tokens.slice(debut, j)
}

/** Les jetons déclarés dans un bloc. */
function jetons(source: string): Set<string> {
  return new Set(
    [...source.matchAll(/^\s*(--[a-z0-9-]+):/gm)].map((m) => m[1]),
  )
}

const clair = bloc(':root {')
const sombreSysteme = bloc(":root:not([data-theme='light'])")
const sombreChoisi = bloc(":root[data-theme='dark']")

describe('la palette est celle de l’application', () => {
  it('le bleu du logo, et pas un violet', () => {
    // #1E40AF vient du marine du logo, en plus saturé. L'application était
    // violette et le logo marine et vert : ils n'ont jamais été d'accord, et
    // chaque retouche de palette déplaçait le problème au lieu de le régler.
    expect(clair).toContain('--c-accent: #1e40af')

    // Aucune trace du violet d'avant, dans aucun des trois blocs.
    for (const [nom, source] of [
      ['clair', clair],
      ['sombre système', sombreSysteme],
      ['sombre choisi', sombreChoisi],
    ] as const) {
      expect(
        source.toLowerCase(),
        `le violet de l’ancienne palette est revenu dans le bloc ${nom}`,
      ).not.toContain('9d86ff')
    }
  })

  it('les valeurs viennent du fichier Flutter, pas d’une approximation', () => {
    // La source unique est `app_colors.dart`. Deux palettes recopiées à la
    // main divergent à la première retouche, et le symptôme est un site qui
    // ressemble à l'application sans en être.
    const dart = readFileSync(
      '../mobile/lib/core/theme/app_colors.dart',
      'utf-8',
    )
    const couple: [string, string][] = [
      ['--c-accent', 'primary'],
      ['--c-hero-start', 'heroStart'],
      ['--c-hero-end', 'heroEnd'],
      ['--c-highlight', 'accent'],
      ['--c-surface-dark', 'surfaceDark'],
      ['--c-band-soft', 'bandSoft'],
      ['--c-ink', 'textPrimary'],
      ['--c-ink-muted', 'textSecondary'],
      ['--c-ink-faint', 'textTertiary'],
      ['--c-border', 'border'],
      ['--c-success', 'success'],
      ['--c-warning', 'warning'],
      ['--c-danger', 'danger'],
    ]

    for (const [jeton, champ] of couple) {
      const ici = clair.match(
        new RegExp(`${jeton}:\\s*#([0-9a-fA-F]{6})`),
      )?.[1]
      const laBas = dart.match(
        new RegExp(`${champ}\\s*=\\s*Color\\(0xFF([0-9A-Fa-f]{6})\\)`),
      )?.[1]
      expect(ici, `${jeton} absent du site`).toBeTruthy()
      expect(laBas, `${champ} absent de app_colors.dart`).toBeTruthy()
      expect(
        ici!.toLowerCase(),
        `${jeton} (#${ici}) ne vaut pas ${champ} (#${laBas})`,
      ).toBe(laBas!.toLowerCase())
    }
  })
})

describe('le mode sombre ne laisse aucune couleur derrière lui', () => {
  /*
   * La liste des jetons qui **portent** une couleur de marque. Un mode sombre
   * qui en oublie un laisse une teinte du mode clair sur une page sombre, et
   * c'est exactement ce qui s'est produit : le dégradé restait bleu vif
   * pendant que les boutons passaient au violet.
   */
  const PORTEURS = [
    '--c-accent',
    '--c-accent-strong',
    '--c-accent-soft',
    '--c-on-accent',
    '--c-hero-start',
    '--c-hero-end',
    '--c-highlight',
    '--c-surface-dark',
    '--c-band-soft',
    '--c-bg',
    '--c-surface',
    '--c-border',
    '--c-ink',
    '--c-ink-muted',
    '--c-ink-faint',
  ]

  it('le bloc système redéfinit tout ce qui porte une couleur', () => {
    const declares = jetons(sombreSysteme)
    for (const jeton of PORTEURS) {
      expect(
        declares.has(jeton),
        `${jeton} garde sa valeur claire en mode sombre`,
      ).toBe(true)
    }
  })

  it('le choix manuel dit exactement la même chose que le réglage système', () => {
    /*
     * Les deux blocs sont dupliqués, et c'est volontaire :
     * `:root:not([data-theme='light'])` ne vaut que dans la requête média, et
     * un sélecteur groupé invalide ferait tomber le bloc entier chez un
     * navigateur qui ne comprend pas l'un des deux.
     *
     * Le prix d'une duplication est qu'elle dérive. Ce test est ce qui
     * l'empêche : les deux blocs doivent déclarer les mêmes jetons avec les
     * mêmes valeurs.
     */
    const lire = (source: string) =>
      new Map(
        [...source.matchAll(/^\s*(--[a-z0-9-]+):\s*([^;]+);/gm)].map((m) => [
          m[1],
          m[2].trim(),
        ]),
      )

    const auto = lire(sombreSysteme)
    const manuel = lire(sombreChoisi)

    for (const [jeton, valeur] of auto) {
      expect(
        manuel.get(jeton),
        `${jeton} vaut « ${valeur} » au réglage système et « ${manuel.get(jeton)} » au choix manuel`,
      ).toBe(valeur)
    }
  })
})

describe('les jetons ne se déclarent qu’une fois', () => {
  it('aucun doublon dans le bloc clair', () => {
    /*
     * `--measure` était déclaré deux fois — 68ch puis 62ch. Seule la seconde
     * agissait ; la première se lisait comme la règle en vigueur par celui
     * qui reprenait le fichier, et toute correction portée sur elle n'avait
     * aucun effet.
     */
    const vus = new Map<string, number>()
    for (const m of clair.matchAll(/^\s*(--[a-z0-9-]+):/gm)) {
      vus.set(m[1], (vus.get(m[1]) ?? 0) + 1)
    }
    const doubles = [...vus].filter(([, n]) => n > 1).map(([nom]) => nom)
    expect(doubles, 'jetons déclarés deux fois').toEqual([])
  })
})

describe('la typographie fait une hiérarchie', () => {
  it('les titres sont fluides et montent au-dessus de 36 px', () => {
    // Le mobile monte à 36 px en 800. Le site plafonnait à 32 px en 700 sur
    // un téléphone comme sur un écran de 27 pouces : un titre qui ne pèse pas
    // plus que son sous-titre ne fait pas de hiérarchie, il fait deux
    // paragraphes.
    expect(tokens).toMatch(/--t-hero:\s*clamp\(/)
    expect(tokens).toMatch(/--t-display:\s*clamp\(/)
    expect(tokens).toContain('--w-heading: 800')
  })

  it('Poppins pour les titres, Inter pour le corps', () => {
    // Poppins au-dessus de 20 px seulement : sa géométrie ronde porte un
    // grand titre, sa hauteur d'x plus courte la dessert en petit.
    expect(tokens).toMatch(/--font-heading:\s*'Poppins'/)
    expect(tokens).toMatch(/--font-sans:\s*'Inter'/)
  })
})
