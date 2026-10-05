/// Cours à domicile : statut d'une demande et règles de passage.
enum TutoringStatus {
  sent('SENT', 'En attente de réponse'),
  accepted('ACCEPTED', 'Acceptée'),
  declined('DECLINED', 'Refusée'),
  cancelled('CANCELLED', 'Annulée');

  const TutoringStatus(this.code, this.label);
  final String code;
  final String label;

  static TutoringStatus fromCode(String? code) => TutoringStatus.values
      .firstWhere((s) => s.code == code, orElse: () => TutoringStatus.sent);

  /// Plus aucune suite possible.
  bool get isFinal => this == declined || this == cancelled;
}

/// Qui agit sur une demande.
enum TutoringActor { parent, teacher }

/// Lieu du cours.
enum TutoringMode {
  atStudent('AT_STUDENT', 'Chez l’élève'),
  atTeacher('AT_TEACHER', 'Chez le professeur'),
  online('ONLINE', 'À distance');

  const TutoringMode(this.code, this.label);
  final String code;
  final String label;

  static TutoringMode fromCode(String? code) => TutoringMode.values.firstWhere(
    (m) => m.code == code,
    orElse: () => TutoringMode.atStudent,
  );
}

/// Une transition est-elle permise ?
///
/// Le professeur répond à une demande en attente. Le parent peut annuler tant
/// que la demande n'est pas close — y compris après acceptation : un parent
/// doit pouvoir renoncer à des cours qu'il n'a pas encore commencés.
///
/// Fonction pure : c'est la règle qu'aucun écran ne doit pouvoir contourner,
/// elle se teste donc sans base ni interface.
bool canSetTutoringStatus({
  required TutoringActor actor,
  required TutoringStatus from,
  required TutoringStatus to,
}) {
  if (from.isFinal || from == to) return false;
  return switch (actor) {
    TutoringActor.teacher =>
      from == TutoringStatus.sent &&
          (to == TutoringStatus.accepted || to == TutoringStatus.declined),
    TutoringActor.parent => to == TutoringStatus.cancelled,
  };
}

/// Un parent peut-il envoyer une nouvelle demande pour cette offre ?
///
/// Non s'il en a déjà une en cours pour le même enfant : sans ce verrou, un
/// double appui envoie deux demandes et le professeur voit deux familles.
bool canRequestTutoring(Iterable<TutoringStatus> existingForSameChild) =>
    !existingForSameChild.any((s) => !s.isFinal);

/// Jour de la semaine, pour les disponibilités.
enum Weekday {
  monday('MON', 'Lundi', 'L'),
  tuesday('TUE', 'Mardi', 'M'),
  wednesday('WED', 'Mercredi', 'M'),
  thursday('THU', 'Jeudi', 'J'),
  friday('FRI', 'Vendredi', 'V'),
  saturday('SAT', 'Samedi', 'S'),
  sunday('SUN', 'Dimanche', 'D');

  const Weekday(this.code, this.label, this.initial);
  final String code;
  final String label;
  final String initial;

  static Weekday? fromCode(String? code) {
    for (final d in Weekday.values) {
      if (d.code == code) return d;
    }
    return null;
  }
}

/// Moment de la journée.
enum DaySlot {
  morning('MORNING', 'Matin', '8 h – 12 h'),
  afternoon('AFTERNOON', 'Après-midi', '12 h – 18 h'),
  evening('EVENING', 'Soirée', '18 h – 21 h');

  const DaySlot(this.code, this.label, this.hours);
  final String code;
  final String label;
  final String hours;

  static DaySlot? fromCode(String? code) {
    for (final s in DaySlot.values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// Nombre minimum de jours pour donner des cours à domicile.
///
/// En dessous, une famille ne peut pas caler un rythme régulier : deux
/// créneaux par semaine suffisent rarement à suivre un programme.
const int minTutoringDays = 3;

/// La disponibilité déclarée permet-elle de publier une offre ?
bool isTutoringAvailabilityValid({
  required Set<Weekday> days,
  required Set<DaySlot> slots,
}) => days.length >= minTutoringDays && slots.isNotEmpty;

/// Ce qui manque, dit en une phrase affichable telle quelle.
String? tutoringAvailabilityProblem({
  required Set<Weekday> days,
  required Set<DaySlot> slots,
}) {
  if (days.length < minTutoringDays) {
    final missing = minTutoringDays - days.length;
    return 'Choisissez encore $missing jour${missing > 1 ? "s" : ""} : '
        'il en faut $minTutoringDays au minimum.';
  }
  if (slots.isEmpty) return 'Choisissez au moins un moment de la journée.';
  return null;
}
