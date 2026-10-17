/**
 * Ce qu'on dit quand l'inscription ou la connexion échoue.
 *
 * --- Le défaut que ce module corrige ------------------------------------
 *
 * `register` traduisait **toute** erreur de `auth.signUp` par « Ce numéro a
 * peut-être déjà un compte. Essayez de vous connecter. » Signalé le 17/10 :
 * Supabase répondait `429` — trop de tentatives depuis la même adresse — et
 * la personne était envoyée se connecter à un compte qui n'existait pas.
 * Elle essayait, la connexion échouait aussi, et le parcours s'arrêtait là.
 *
 * Un message faux coûte plus cher qu'un message vague : il envoie quelque
 * part. Chaque cause a donc sa phrase, et chacune dit quoi faire.
 *
 * --- Pourquoi un module à part ------------------------------------------
 *
 * Ces règles se vérifient sans réseau et sans base. Une correspondance
 * d'erreurs qu'on ne peut éprouver qu'en provoquant la panne n'est jamais
 * éprouvée — et c'est précisément quand tout va mal qu'elle doit être juste.
 */

/** Ce que rend Supabase : un statut, un message, parfois un code. */
export interface EchecAuth {
  status?: number
  message?: string
  code?: string
}

export interface Verdict {
  message: string
  status: number
}

const contient = (echec: EchecAuth, ...bouts: string[]): boolean => {
  /*
   * Les soulignes deviennent des espaces avant la comparaison.
   *
   * Supabase donne la meme cause sous deux formes : le message dit
   * « Request rate limit reached » et le code `over_request_rate_limit`.
   * Chercher « rate limit » attrapait le premier et manquait le second —
   * et c'est le code qui arrive quand le message est vide.
   */
  const texte = `${echec.code ?? ''} ${echec.message ?? ''}`
    .toLowerCase()
    .replace(/_/g, ' ')
  return bouts.some((bout) => texte.includes(bout.replace(/_/g, ' ')))
}

/**
 * Trop de tentatives.
 *
 * Supabase limite les inscriptions par adresse IP. Dans un cybercafé ou
 * derrière le partage de connexion d'un téléphone, plusieurs personnes
 * sortent par la même adresse : la limite se touche sans que personne n'ait
 * rien fait de mal. Le message doit donc dire d'attendre, pas de renoncer.
 */
const TROP = {
  message:
    'Trop de tentatives depuis cette connexion. Attendez quelques minutes, '
    + 'puis réessayez — votre saisie est conservée.',
  status: 429,
}

export function messageInscription(echec: EchecAuth): Verdict {
  if (echec.status === 429 || contient(echec, 'rate limit', 'too many')) {
    return TROP
  }

  if (
    contient(echec, 'already registered', 'already exists', 'user_already')
  ) {
    return {
      message: 'Ce numéro a déjà un compte. Essayez de vous connecter.',
      status: 409,
    }
  }

  if (contient(echec, 'weak_password', 'password should be')) {
    return {
      message:
        'Mot de passe trop simple. Prenez six caractères ou plus, sans '
        + 'suite évidente.',
      status: 400,
    }
  }

  /*
   * Le numéro est transformé en adresse de courriel avant d'être envoyé à
   * Supabase. Un refus sur ce champ veut dire que le numéro n'a pas la
   * forme attendue — et c'est le numéro qu'il faut corriger, pas l'adresse,
   * dont la personne ignore l'existence.
   */
  if (contient(echec, 'email', 'invalid')) {
    return {
      message:
        'Ce numéro n’a pas la forme attendue : 9 chiffres, sans l’indicatif.',
      status: 400,
    }
  }

  if (echec.status && echec.status >= 500) {
    return {
      message:
        'Le serveur n’a pas répondu. Votre compte n’a pas été créé — '
        + 'réessayez dans un instant.',
      status: 502,
    }
  }

  /*
   * Le message du serveur plutôt qu'une phrase passe-partout.
   *
   * On ne sait pas ce qui s'est passé ; le dire est plus honnête que de
   * deviner, et le texte brut aide qui nous le rapportera.
   */
  return {
    message:
      echec.message?.trim()
        ? `L’inscription n’a pas abouti : ${echec.message.trim()}`
        : 'L’inscription n’a pas abouti. Réessayez dans un instant.',
    status: echec.status ?? 400,
  }
}

export function messageConnexion(echec: EchecAuth): Verdict {
  if (echec.status === 429 || contient(echec, 'rate limit', 'too many')) {
    return TROP
  }

  /*
   * Un seul message pour « numéro inconnu » et « mot de passe faux ».
   *
   * Les distinguer dirait à un inconnu quels numéros ont un compte. C'est
   * la seule ambiguïté qu'on garde volontairement, et elle ne coûte rien :
   * dans les deux cas, le geste à faire est le même.
   */
  return { message: 'Numéro ou mot de passe incorrect.', status: 401 }
}
