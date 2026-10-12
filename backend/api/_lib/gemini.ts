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

/** Le prix d'un appel, au tarif d'après promotion (voir models.json). */
export function coutUsd(input: {
  model: string
  tokensIn: number
  tokensOut: number
}): number {
  const tarif =
    input.model === catalogue.models.build.id
      ? catalogue.models.build
      : catalogue.models.chat
  const dollars =
    (input.tokensIn / 1_000_000) * tarif.usdPerMillionIn
    + (input.tokensOut / 1_000_000) * tarif.usdPerMillionOut
  // Six décimales, comme la colonne `ai_usage.cost_usd` : un message coûte
  // 0,002 $, arrondir au centime écrirait zéro sur chaque ligne.
  return Math.round(dollars * 1_000_000) / 1_000_000
}

/** Ce qu'un appel a réellement consommé. */
export interface GeminiUsage {
  text: string
  tokensIn: number
  tokensOut: number
  model: string
}

/** Un tour de parole, dans l'ordre où il a été dit. */
export interface GeminiTurn {
  role: 'USER' | 'MODEL'
  body: string
}

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
    prompt: string | GeminiTurn[],
    options: {
      maxOutputTokens?: number
      temperature?: number
      /** Consignes système, versionnées par l'appelant. */
      system?: string
    } = {},
  ): Promise<GeminiUsage> {
    const corps = {
      contents:
        typeof prompt === 'string'
          ? [{ role: 'user', parts: [{ text: prompt }] }]
          : prompt.map((tour) => ({
              // Google nomme `model` ce que nous nommons `MODEL`, et `user`
              // ce que nous nommons `USER`. La traduction se fait ici, une
              // fois : les tables et le reste du code gardent nos noms.
              role: tour.role === 'MODEL' ? 'model' : 'user',
              parts: [{ text: tour.body }],
            })),
      ...(options.system
        ? { systemInstruction: { parts: [{ text: options.system }] } }
        : {}),
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
        // Un refus de sécurité arrive ici : la réponse est valide, mais vide,
        // et `finishReason` dit « SAFETY ». Le distinguer d'une panne change
        // ce qu'on affiche — « reformulez » plutôt que « réessayez ».
        const raison = (premier as Record<string, unknown> | undefined)
          ?.finishReason
        if (raison === 'SAFETY' || raison === 'PROHIBITED_CONTENT') {
          throw new GeminiError(
            'Cette question n’a pas pu être traitée. Reformulez-la, ou '
              + 'posez-la autrement.',
            422,
          )
        }
        throw new GeminiError('Gemini a repondu sans texte.')
      }

      // Les jetons réellement comptés par Google, et non une estimation : le
      // plafond mensuel ne vaut que s'il additionne la même chose que la
      // facture. Absents sur certaines réponses — zéro alors, et la ligne de
      // journal le dira par un coût nul.
      const compteur = donnees.usageMetadata as
        | Record<string, unknown>
        | undefined
      return {
        text: texte.trim(),
        tokensIn: Number(compteur?.promptTokenCount) || 0,
        tokensOut: Number(compteur?.candidatesTokenCount) || 0,
        model,
      }
    }
  }

  /**
   * Un tour de conversation avec l'assistant.
   *
   * --- Ce qui part chez Google, et ce qui n'en part pas -------------------
   *
   * Le module pose depuis le premier jour qu'aucune donnée personnelle ne le
   * traverse. Un assistant de devoirs met cette règle à l'épreuve, puisque la
   * question de l'élève part forcément. Ce qui reste tenu, et que l'appelant
   * doit tenir avec lui :
   *
   *   * l'historique envoyé ne contient que des questions et des réponses —
   *     ni prénom, ni identifiant de compte, ni ville, ni nom d'école ;
   *   * les consignes système décrivent un rôle, pas une personne.
   *
   * Google ne peut donc pas relier deux conversations au même enfant.
   *
   * --- Pourquoi l'historique complet et non le dernier message -----------
   *
   * « Et pour la question 3 ? » ne veut rien dire seul. Le modèle n'a pas de
   * mémoire entre deux appels : c'est nous qui la lui rendons, et c'est aussi
   * pour cela que l'historique est **borné** par l'appelant — vingt tours de
   * parole feraient grossir l'entrée, donc la facture, sans améliorer la
   * réponse.
   */
  async converse(input: {
    history: GeminiTurn[]
    system: string
    maxOutputTokens?: number
  }): Promise<GeminiUsage> {
    if (input.history.length === 0) {
      throw new GeminiError('Aucune question a poser.', 400)
    }
    return this.generate(MODELS.chat, input.history, {
      system: input.system,
      // Assez pour une explication en trois paragraphes avec un exemple
      // chiffré. Au-delà, le modèle reformule ce qu'il vient de dire.
      maxOutputTokens: input.maxOutputTokens ?? 900,
      // Plus haut que pour un résumé de chiffres : une explication a besoin
      // de reformuler, de choisir un exemple. Trop bas, elle récite.
      temperature: 0.6,
    })
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

    return (await this.generate(MODELS.chat, invite)).text
  }
}
