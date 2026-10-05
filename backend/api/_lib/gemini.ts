import catalogue from '../../../shared/ai/models.json' with { type: 'json' }

/**
 * Gemini — le seul module du Worker qui parle à Google.
 *
 * Point de sortie unique, comme Djomy, LiveKit, R2 et Stream : changer de modèle,
 * fournisseur ou de barème ne doit toucher que ce fichier.
 *
 * --- La clé ---------------------------------------------------------------
 *
 * Elle ne vit que dans `backend/.env`, jamais ailleurs. Deux raisons, et la
 * seconde est la plus concrète :
 *
 *   * une clé préfixée `VITE_` serait **recopiée dans le paquet du site** par
 *     Vite, donc lisible par n'importe quel visiteur. Le constructeur refuse
 *     une clé qui porte ce préfixe plutôt que de la laisser passer ;
 *   * l'APK circule par Bluetooth et par Xender et se décompile en quelques
 *     minutes. Une clé embarquée côté client est une clé publique, facturée à
 *     nous.
 *
 * --- L'offre payante -----------------------------------------------------
 *
 * ⚠ En offre gratuite, Google se sert des données envoyées pour améliorer ses
 * produits. L'API ne dit pas de quelle offre relève une clé : ce point se
 * vérifie à la main, et `scripts/check-gemini.mjs` le rappelle.
 *
 * --- Ce qu'on n'envoie jamais --------------------------------------------
 *
 * **Aucune donnée personnelle ne quitte le serveur par ce module.** Pour le
 * résumé d'un point de contrôle, Google reçoit la matière, le numéro du module
 * et trois nombres — « 9 ont compris, 4 pas assez, 2 non ». Pas un prénom, pas
 * un identifiant, pas une phrase écrite par un élève.
 *
 * Ce n'est pas une précaution de forme : c'est ce qui rend la question de
 * l'offre payante secondaire pour cet usage précis. Il n'y a rien à fuiter.
 * Chaque nouvel appel ajouté ici doit tenir la même règle, et c'est à
 * l'appelant de construire une invite qui ne porte pas de noms.
 */

const API = 'https://generativelanguage.googleapis.com/v1beta'

/** Les modèles, lus depuis la source partagée. */
export const MODELS = {
  build: catalogue.models.build.id,
  chat: catalogue.models.chat.id,
} as const

export class GeminiError extends Error {
  readonly status: number

  constructor(message: string, status = 502) {
    super(message)
    this.status = status
    this.name = 'GeminiError'
  }
}

export interface GeminiConfig {
  apiKey: string
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))

export class Gemini {
  private readonly apiKey: string

  constructor(config: GeminiConfig) {
    if (config.apiKey.startsWith('VITE_')) {
      // Le préfixe trahit une clé copiée depuis un fichier de client. Refuser
      // au démarrage vaut mieux que de découvrir la fuite dans un paquet publié.
      throw new GeminiError(
        'GEMINI_API_KEY porte le prefixe VITE_ : cette cle a ete prevue pour un '
          + 'client et ne doit pas servir cote serveur.',
        500,
      )
    }
    this.apiKey = config.apiKey
  }

  static isConfigured(config: Partial<GeminiConfig>): config is GeminiConfig {
    return Boolean(config.apiKey && config.apiKey.trim().length > 20)
  }

  /**
   * Un appel de génération, avec reprises sur les refus passagers.
   *
   * Google renvoie des `503 high demand` qui durent quelques secondes. Sans
   * reprise, un professeur perdrait son résumé au moment précis où il en a
   * besoin — pendant la pause de cinq minutes.
   *
   * Les autres codes ne sont **pas** réessayés : un 400 est une invite mal
   * formée et un 429 un plafond atteint. Insister ne ferait qu'ajouter du
   * retard à une erreur certaine.
   */
  private async generate(
    model: string,
    prompt: string,
    options: { maxOutputTokens?: number; temperature?: number } = {},
  ): Promise<string> {
    const corps = {
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        // Court par construction : un résumé qu'on lit pendant une pause de
        // cinq minutes ne fait pas trois paragraphes.
        maxOutputTokens: options.maxOutputTokens ?? 320,
        // Bas : on résume des chiffres, on n'écrit pas un poème. Une
        // température haute inventerait des nuances que les données ne portent
        // pas.
        temperature: options.temperature ?? 0.2,
      },
    }

    const essais = Number(catalogue.retries) || 3
    for (let essai = 1; ; essai += 1) {
      let reponse: Response
      try {
        reponse = await fetch(`${API}/models/${model}:generateContent`, {
          method: 'POST',
          headers: {
            'x-goog-api-key': this.apiKey,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(corps),
          signal: AbortSignal.timeout(Number(catalogue.timeoutMs) || 20000),
        })
      } catch (cause) {
        if (essai >= essais) {
          throw new GeminiError(
            `Gemini injoignable : ${cause instanceof Error ? cause.message : cause}`,
            503,
          )
        }
        await sleep(essai * 1000)
        continue
      }

      if (reponse.status === 503 && essai < essais) {
        await sleep(essai * 1000)
        continue
      }

      const donnees = (await reponse.json().catch(() => ({}))) as Record<
        string,
        unknown
      >

      if (!reponse.ok) {
        const erreur = donnees.error as Record<string, unknown> | undefined
        // Le message de Google, jamais la clé : elle n'apparaît pas dans les
        // réponses, et ce commentaire est là pour qu'on ne l'y ajoute pas en
        // journalisant l'en-tête.
        throw new GeminiError(
          (erreur?.message as string) ?? `Gemini a refuse (${reponse.status}).`,
          reponse.status,
        )
      }

      const candidats = donnees.candidates
      const premier = Array.isArray(candidats) ? candidats[0] : undefined
      const contenu = (premier as Record<string, unknown> | undefined)?.content
      const parties = (contenu as Record<string, unknown> | undefined)?.parts
      const texte = Array.isArray(parties)
        ? parties
            .map((p) => (p as Record<string, unknown>).text)
            .filter((t): t is string => typeof t === 'string')
            .join('')
        : ''

      if (texte.trim() === '') {
        throw new GeminiError('Gemini a repondu sans texte.')
      }
      return texte.trim()
    }
  }

  /**
   * Résume ce qui n'est pas passé dans un module, pour le professeur.
   *
   * **Entrée sans aucune donnée personnelle** : la matière, le numéro du module
   * et trois décomptes. Rien ne permet d'identifier un élève, donc rien ne
   * fuite — et c'est à cette condition que l'appel est acceptable.
   *
   * **Sortie : une aide, pas une note.** Deux ou trois phrases que le professeur
   * lit pendant la pause de cinq minutes. Elle n'entre dans aucun score, et le
   * schéma le redit (`session_checkpoints.summary`).
   */
  async summariseCheckpoint(input: {
    subject: string
    level: string
    moduleIndex: number
    yes: number
    partly: number
    no: number
    /** Titre du module, s'il en a un. Jamais un nom de personne. */
    topic?: string
  }): Promise<string> {
    const total = input.yes + input.partly + input.no
    if (total === 0) {
      // Pas d'appel du tout : il n'y a rien à résumer, et une invite sur zéro
      // réponse produirait une phrase inventée.
      throw new GeminiError('Aucune reponse a resumer.', 400)
    }

    const invite = [
      'Tu aides un professeur guinéen pendant une pause de 5 minutes, au milieu',
      "d'un cours en direct de 90 minutes avec 15 élèves au maximum.",
      '',
      `Matière : ${input.subject}. Classe : ${input.level}.`,
      `Module ${input.moduleIndex + 1} sur 4${input.topic ? ` — ${input.topic}` : ''}.`,
      '',
      'Les élèves viennent de répondre à « est-ce passé ? » :',
      `- ${input.yes} ont compris`,
      `- ${input.partly} pas assez`,
      `- ${input.no} n'ont pas compris`,
      '',
      'Écris en français, 2 à 3 phrases maximum, à la deuxième personne.',
      'Dis ce que ces chiffres impliquent concrètement pour les 5 minutes qui',
      'viennent : reprendre, avancer, ou poser une question de vérification.',
      "Sois direct, sans formule de politesse et sans répéter les chiffres tels",
      'quels.',
      "N'invente aucune information sur un élève en particulier : tu ne sais rien",
      "d'eux, et tu ne dois rien supposer.",
    ].join('\n')

    return this.generate(MODELS.chat, invite)
  }
}
