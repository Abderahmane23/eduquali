/**
 * Un numéro guinéen, ramené à sa forme unique.
 *
 * --- Le défaut que ce module corrige ------------------------------------
 *
 * L'adresse du compte est dérivée du numéro : il n'y a pas de boîte derrière,
 * c'est un identifiant stable faute de fournisseur SMS. La dérivation ne
 * gardait que les chiffres. Le même numéro, tapé de trois façons, donnait
 * donc trois comptes différents :
 *
 *     620000101        ->  620000101@telephone.eduquali.gn
 *     +224620000101    ->  224620000101@telephone.eduquali.gn
 *     0620000101       ->  0620000101@telephone.eduquali.gn
 *
 * Le champ affiche bien « +224 » à gauche, non modifiable, et l'indice dit
 * « 9 chiffres ». Mais on colle un numéro depuis ses contacts, où il est
 * enregistré en entier — et rien ne l'empêche : le champ accepte douze
 * caractères.
 *
 * Les conséquences se voient à deux moments, et jamais au bon :
 *
 *   * à l'inscription, on crée un second compte sans le savoir — l'écran dit
 *     « compte créé », tout se passe bien, et les paiements, les cours et les
 *     enfants du premier compte sont ailleurs ;
 *   * à la connexion, Supabase répond **400** sur
 *     `/auth/v1/token?grant_type=password` — « identifiants invalides » pour
 *     un numéro dont la personne est sûre, et elle l'est : c'est bien le sien.
 *
 * --- La forme retenue ----------------------------------------------------
 *
 * **Neuf chiffres, sans indicatif ni zéro de tête.** C'est la forme qu'un
 * Guinéen dicte, celle qu'affichent les écrans, et celle que le champ
 * demande. L'indicatif est porté par le préfixe non modifiable, où il
 * n'ajoute aucune ambiguïté.
 *
 * --- Pourquoi un module à part, et pure --------------------------------
 *
 * Cette fonction décide de **l'identité d'un compte**. Elle doit être
 * vérifiable sans réseau, sans base et sans navigateur, et elle doit dire la
 * même chose que son jumeau Dart — `SupabaseAuthApi.emailFor`, côté mobile.
 * Deux formules qui divergent feraient deux comptes pour la même personne, et
 * ce serait invisible jusqu'au jour où elle change d'appareil.
 */

/**
 * Les neuf chiffres d'un numéro guinéen, quelle que soit la façon de le taper.
 *
 * Rend la saisie nettoyée telle quelle si elle ne ressemble pas à un numéro
 * guinéen : ce module identifie, il ne valide pas. Refuser ici
 * transformerait une faute de frappe en page blanche, alors que la
 * validation du champ a déjà un message à offrir.
 */
export function numeroNational(saisi: string): string {
  let chiffres = saisi.replace(/\D/g, '')

  /*
   * On pèle de l'extérieur vers l'intérieur, et dans cet ordre : le code de
   * sortie international, puis l'indicatif du pays, puis le zéro de tête.
   *
   * L'ordre a été trouvé par une épreuve qui a échoué : `00224620000101` —
   * la forme qu'enregistrent les téléphones d'avant le « + », et qu'on
   * retrouve dans les carnets d'adresses anciens. En commençant par
   * l'indicatif, `224` n'était pas en tête, rien n'était retiré, et le `0`
   * seul laissait `0224620000101` : un troisième compte pour la même
   * personne. Peler par l'extérieur règle les trois cas d'un coup.
   *
   * Chaque retrait exige qu'il reste **plus** de neuf chiffres. Un abonné
   * dont les neuf chiffres commencent par 224 ou par 0 garde donc les siens :
   * lui couper son numéro lui ferait perdre son compte, ce qui est pire que
   * l'ambiguïté qu'on cherche à lever.
   */
  if (chiffres.startsWith('00') && chiffres.length > 9) {
    chiffres = chiffres.slice(2)
  }
  if (chiffres.startsWith('224') && chiffres.length > 9) {
    chiffres = chiffres.slice(3)
  }
  if (chiffres.startsWith('0') && chiffres.length > 9) {
    chiffres = chiffres.slice(1)
  }

  return chiffres
}

/**
 * L'adresse qui identifie le compte.
 *
 * **Doit rester identique à `SupabaseAuthApi.emailFor` du client mobile.**
 */
export function adresseDuCompte(saisi: string): string {
  return `${numeroNational(saisi)}@telephone.eduquali.gn`
}
