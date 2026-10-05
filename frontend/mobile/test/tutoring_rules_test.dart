import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/domain/usecases/tutoring_rules.dart';

/// Cours à domicile — règles de passage d'une demande.
void main() {
  bool can(TutoringActor actor, TutoringStatus from, TutoringStatus to) =>
      canSetTutoringStatus(actor: actor, from: from, to: to);

  const teacher = TutoringActor.teacher;
  const parent = TutoringActor.parent;
  const sent = TutoringStatus.sent;
  const accepted = TutoringStatus.accepted;
  const declined = TutoringStatus.declined;
  const cancelled = TutoringStatus.cancelled;

  group('Le professeur répond', () {
    test('il accepte ou refuse une demande en attente', () {
      expect(can(teacher, sent, accepted), isTrue);
      expect(can(teacher, sent, declined), isTrue);
    });

    test('il ne revient pas sur une demande déjà acceptée', () {
      expect(can(teacher, accepted, declined), isFalse);
    });

    test('il n’annule pas à la place du parent', () {
      expect(can(teacher, sent, cancelled), isFalse);
    });
  });

  group('Le parent', () {
    test('annule une demande en attente', () {
      expect(can(parent, sent, cancelled), isTrue);
    });

    test('annule même après acceptation — cours pas encore commencés', () {
      expect(can(parent, accepted, cancelled), isTrue);
    });

    test('ne s’accepte pas lui-même', () {
      expect(can(parent, sent, accepted), isFalse);
      expect(can(parent, sent, declined), isFalse);
    });
  });

  group('Une demande close reste close', () {
    test('rien ne sort d’un refus ni d’une annulation', () {
      for (final from in [declined, cancelled]) {
        for (final to in TutoringStatus.values) {
          expect(can(teacher, from, to), isFalse, reason: '$from -> $to');
          expect(can(parent, from, to), isFalse, reason: '$from -> $to');
        }
      }
    });

    test('pas de transition vers le statut déjà porté', () {
      expect(can(teacher, sent, sent), isFalse);
    });
  });

  group('Nouvelle demande pour le même enfant', () {
    test('possible s’il n’y en a aucune', () {
      expect(canRequestTutoring(const []), isTrue);
    });

    test('bloquée tant qu’une demande est en cours', () {
      expect(canRequestTutoring(const [sent]), isFalse);
      expect(canRequestTutoring(const [accepted]), isFalse);
    });

    test('possible après un refus ou une annulation', () {
      expect(canRequestTutoring(const [declined, cancelled]), isTrue);
    });
  });

  group('Codes', () {
    test('chaque statut se relit depuis son code', () {
      for (final s in TutoringStatus.values) {
        expect(TutoringStatus.fromCode(s.code), s);
      }
    });

    test('chaque lieu se relit depuis son code', () {
      for (final m in TutoringMode.values) {
        expect(TutoringMode.fromCode(m.code), m);
      }
    });
  });

  group('Disponibilité pour les cours à domicile', () {
    const trois = {Weekday.monday, Weekday.wednesday, Weekday.saturday};
    const matin = {DaySlot.morning};

    test('trois jours et un créneau suffisent', () {
      expect(isTutoringAvailabilityValid(days: trois, slots: matin), isTrue);
      expect(tutoringAvailabilityProblem(days: trois, slots: matin), isNull);
    });

    test('deux jours ne suffisent pas', () {
      const deux = {Weekday.monday, Weekday.friday};
      expect(isTutoringAvailabilityValid(days: deux, slots: matin), isFalse);
      // Le message dit ce qui manque, pas seulement que c'est refusé.
      expect(
        tutoringAvailabilityProblem(days: deux, slots: matin),
        contains('encore 1 jour'),
      );
    });

    test('des jours sans créneau ne suffisent pas', () {
      expect(
        isTutoringAvailabilityValid(days: trois, slots: const {}),
        isFalse,
      );
      expect(
        tutoringAvailabilityProblem(days: trois, slots: const {}),
        contains('moment de la journée'),
      );
    });

    test('rien de déclaré : on demande les trois jours', () {
      expect(
        tutoringAvailabilityProblem(days: const {}, slots: const {}),
        contains('$minTutoringDays au minimum'),
      );
    });

    test('les sept jours et les trois moments se relisent', () {
      expect(Weekday.values, hasLength(7));
      expect(DaySlot.values, hasLength(3));
      for (final d in Weekday.values) {
        expect(Weekday.fromCode(d.code), d);
      }
      for (final s in DaySlot.values) {
        expect(DaySlot.fromCode(s.code), s);
      }
    });
  });
}
