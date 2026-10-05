/// Abonnement mensuel — formules et ce qu'elles ouvrent.
///
/// Remplace le système de crédits du 19/09 (24/09). Les crédits demandaient
/// à chacun de convertir une action en monnaie interne, puis cette monnaie
/// en francs : deux conversions avant de savoir si l'on peut se permettre de
/// publier une annonce. Un abonnement mensuel répond une fois pour toutes.
///
/// Même prix pour tous les profils : un professeur, un établissement, un
/// parent et un étudiant paient la même chose. Une grille par profil oblige
/// à justifier chaque écart, et personne n'a ces chiffres.
///
/// Toutes les valeurs vivent ici et nulle part ailleurs : un écran qui
/// affiche « 100 000 GNF » lit ce fichier, il ne l'écrit pas en dur.
library;

/// Les trois niveaux de compte.
enum SubscriptionPlan {
  /// Sans abonnement. On regarde, on est vu, mais on ne prend pas contact.
  ///
  /// Nomme « Basic » et non « Gratuit » : le mot apparait sur l'ecran de
  /// l'assistant, a cote du titre, et « Gratuit » s'y lisait comme la
  /// promesse que l'assistant l'etait.
  free('FREE', 'Basic', 0),

  /// Le contact direct et la messagerie.
  pro('PRO', 'Pro', 100000),

  /// Pro, plus la visibilité et l'assistant sans limite.
  master('MASTER', 'Master', 200000);

  const SubscriptionPlan(this.code, this.label, this.monthlyPriceGnf);

  final String code;
  final String label;

  /// Prix mensuel en francs guinéens.
  final int monthlyPriceGnf;

  static SubscriptionPlan fromCode(String? code) => SubscriptionPlan.values
      .firstWhere((p) => p.code == code, orElse: () => SubscriptionPlan.free);

  /// La formule mise en avant : celle qui débloque le geste que tout le
  /// monde vient faire — prendre contact.
  static const recommended = SubscriptionPlan.pro;

  /// Ce niveau couvre-t-il [other] ?
  bool covers(SubscriptionPlan other) => index >= other.index;
}

/// Ce que chaque fonction exige.
///
/// Le nom dit la fonction, pas le prix : quand une fonction change de
/// niveau, on modifie une ligne ici et aucun écran.
enum PaidFeature {
  /// Voir les coordonnées d'un professeur et lui écrire.
  contact(SubscriptionPlan.pro),

  /// Mettre un professeur en favori.
  favourites(SubscriptionPlan.pro),

  /// L'assistant : discussion et construction de cours.
  assistant(SubscriptionPlan.pro),

  /// Mettre son établissement en avant dans les listes.
  promotion(SubscriptionPlan.master),

  /// Vendre des cours vidéo.
  sellCourses(SubscriptionPlan.master);

  const PaidFeature(this.requires);

  /// La formule minimale qui l'ouvre.
  final SubscriptionPlan requires;
}

/// La formule courante ouvre-t-elle cette fonction ?
bool allows(SubscriptionPlan plan, PaidFeature feature) =>
    plan.covers(feature.requires);

/// Ce qu'il manque pour y accéder, ou `null` si c'est déjà ouvert.
///
/// Rendre la formule attendue plutôt qu'un simple faux permet à l'écran de
/// dire *laquelle* prendre, au lieu de proposer la liste entière.
SubscriptionPlan? missingPlan(SubscriptionPlan plan, PaidFeature feature) =>
    allows(plan, feature) ? null : feature.requires;

/// Un abonnement reste valable jusqu'à la fin du mois payé.
///
/// Le jour même de l'échéance compte encore : couper à l'heure près punirait
/// un décalage de fuseau ou un paiement enregistré avec quelques minutes de
/// retard.
bool isActive(SubscriptionPlan plan, DateTime? renewsAt, DateTime now) {
  if (plan == SubscriptionPlan.free) return true;
  if (renewsAt == null) return false;
  final fin = DateTime(renewsAt.year, renewsAt.month, renewsAt.day + 1);
  return now.isBefore(fin);
}

/// La formule effective : celle qu'on a payée si elle court encore, sinon
/// le gratuit.
///
/// Un abonnement expiré ne retire rien de ce qui a été créé ; il referme
/// seulement ce qui se paie.
SubscriptionPlan effectivePlan(
  SubscriptionPlan plan,
  DateTime? renewsAt,
  DateTime now,
) => isActive(plan, renewsAt, now) ? plan : SubscriptionPlan.free;
