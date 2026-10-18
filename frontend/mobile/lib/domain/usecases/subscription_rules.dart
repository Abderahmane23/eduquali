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

  /// Quatre cours et deux directs par mois.
  ///
  /// 100 000 GNF jusqu'au 18/10, et « Pro ». Le prix et le nom viennent
  /// desormais de `shared/formules/formules.json`, que lisent aussi le
  /// serveur et ses epreuves : un ecran qui annonce un prix pendant que le
  /// serveur en demande un autre est pire qu'un ecran sans prix.
  pro('PRO', 'Découverte', 50000),

  /// Cours et directs sans limite, assistant sans limite, questions
  /// pendant les directs, exercices corriges.
  master('MASTER', 'Illimité', 200000);

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


// --- Les quotas, et l'essai ------------------------------------------------
//
// Ce qui precede repond par oui ou par non : une fonction est ouverte ou
// fermee. Ce qui suit compte — « deux directs par mois » ne s'exprime pas
// autrement, et c'est ce qui est vendu depuis le 18/10.
//
// **Jumeau de `backend/api/_lib/formules.ts`.** Le serveur reste l'autorite :
// c'est lui qui accorde ou refuse, parce que l'APK circule par Bluetooth et
// se decompile en quelques minutes. Ce module sert a *afficher* — dire ce
// qu'il reste, et pourquoi une porte est fermee, sans attendre un aller-retour.

/// Ce qui se consomme.
enum Ressource { assistant, direct, cours }

/// La periode sur laquelle un quota se remet a zero.
enum Periode { jour, quinzaine, mois, jamais }

/// Une limite : `max` a `null` veut dire sans limite.
class Quota {
  const Quota(this.max, this.periode);
  final int? max;
  final Periode periode;
}

/// Sept jours, et ce qu'ils ouvrent.
const int joursEssai = 7;

/// Trois questions par jour, essai compris.
///
/// Chaque question part chez un fournisseur facture au jeton : offrir
/// l'assistant sans limite pendant sept jours reviendrait a payer la
/// curiosite de qui ne restera pas.
const int assistantParJour = 3;

const Map<Ressource, Quota> _quotasGratuit = {
  Ressource.assistant: Quota(assistantParJour, Periode.jour),
  Ressource.direct: Quota(1, Periode.quinzaine),
  Ressource.cours: Quota(1, Periode.mois),
};

const Map<Ressource, Quota> _quotasDecouverte = {
  Ressource.assistant: Quota(assistantParJour, Periode.jour),
  Ressource.direct: Quota(2, Periode.mois),
  Ressource.cours: Quota(4, Periode.mois),
};

const Map<Ressource, Quota> _quotasIllimite = {
  Ressource.assistant: Quota(null, Periode.jamais),
  Ressource.direct: Quota(null, Periode.jamais),
  Ressource.cours: Quota(null, Periode.jamais),
};

/// L'essai : tout ouvert, sauf l'assistant qui garde son plafond.
const Map<Ressource, Quota> quotasEssai = {
  Ressource.assistant: Quota(assistantParJour, Periode.jour),
  Ressource.direct: Quota(null, Periode.jamais),
  Ressource.cours: Quota(null, Periode.jamais),
};

/// Les quotas d'une formule.
Map<Ressource, Quota> quotasDe(SubscriptionPlan plan) => switch (plan) {
  SubscriptionPlan.free => _quotasGratuit,
  SubscriptionPlan.pro => _quotasDecouverte,
  SubscriptionPlan.master => _quotasIllimite,
};

/// Le compte est-il encore dans ses sept premiers jours ?
bool dansLEssai(DateTime creeLe, DateTime maintenant) =>
    maintenant.isBefore(creeLe.add(const Duration(days: joursEssai)));

/// Ce qu'il reste d'essai, en jours entiers — 0 s'il est fini.
///
/// Un jour entame compte pour un jour entier : arrondir vers le bas dirait
/// « il reste 1 jour » a quelqu'un qui en a encore un et demi, et l'ecran
/// qui pousse a s'abonner mentirait dans le sens qui l'arrange.
int joursDEssaiRestants(DateTime creeLe, DateTime maintenant) {
  final reste = creeLe
      .add(const Duration(days: joursEssai))
      .difference(maintenant);
  if (reste.isNegative || reste == Duration.zero) return 0;
  return (reste.inMilliseconds / Duration.millisecondsPerDay).ceil();
}

/// Les quotas qui s'appliquent vraiment, essai compris.
Map<Ressource, Quota> quotasEffectifs({
  required SubscriptionPlan plan,
  required DateTime? renouvelleLe,
  required DateTime creeLe,
  required DateTime maintenant,
}) {
  if (plan != SubscriptionPlan.free &&
      isActive(plan, renouvelleLe, maintenant)) {
    return quotasDe(plan);
  }
  return dansLEssai(creeLe, maintenant) ? quotasEssai : _quotasGratuit;
}

/// Le nom a afficher, essai compris.
String nomDeLaFormule({
  required SubscriptionPlan plan,
  required DateTime? renouvelleLe,
  required DateTime creeLe,
  required DateTime maintenant,
}) {
  if (plan != SubscriptionPlan.free &&
      isActive(plan, renouvelleLe, maintenant)) {
    return plan.label;
  }
  return dansLEssai(creeLe, maintenant) ? 'Essai' : SubscriptionPlan.free.label;
}

/// Ce qu'il reste sur un quota, ou `null` s'il est sans limite.
int? restantSur(Quota quota, int consomme) {
  final max = quota.max;
  if (max == null) return null;
  final utilise = consomme < 0 ? 0 : consomme;
  final reste = max - utilise;
  return reste < 0 ? 0 : reste;
}
