/// Quand deux messages n'en forment plus qu'un bloc.
///
/// --- Pourquoi cette règle existe -----------------------------------------
///
/// Dans un groupe de quinze, une personne écrit souvent trois lignes de suite.
/// Réimprimer son nom et son avatar à chaque fois remplit l'écran de noms
/// répétés et pousse le texte dehors. Les messageries modernes regroupent donc
/// les messages consécutifs d'un même auteur sous un seul en-tête.
///
/// --- Pourquoi une fonction et non un `if` dans le widget ----------------
///
/// C'est une règle, avec une borne de temps choisie, et une règle se vérifie.
/// Dans la liste, elle serait exercée par un test d'interface qui monte un
/// écran entier pour éprouver une comparaison de dates.
library;

/// Au-delà, deux messages du même auteur redeviennent deux prises de parole.
///
/// Cinq minutes : en dessous, une réponse à une question posée entre-temps se
/// collerait au bloc précédent et paraîtrait venir de la même pensée. Bien
/// au-dessus, deux messages d'une même minute se sépareraient pour rien.
const Duration memeBloc = Duration(minutes: 5);

/// Ce message prolonge-t-il le bloc du précédent ?
///
/// [precedentAuteur] est nul en tête de liste : le premier message ouvre
/// toujours son bloc.
bool prolongeLeBloc({
  required String? precedentAuteur,
  required DateTime? precedentEnvoi,
  required String auteur,
  required DateTime envoi,
}) {
  if (precedentAuteur == null || precedentEnvoi == null) return false;
  if (precedentAuteur != auteur) return false;
  // Négatif si l'horloge d'un téléphone est en avance : un message daté avant
  // son prédécesseur ouvre son propre bloc plutôt que de se cacher dans le
  // précédent.
  final ecart = envoi.difference(precedentEnvoi);
  if (ecart.isNegative) return false;
  return ecart < memeBloc;
}
