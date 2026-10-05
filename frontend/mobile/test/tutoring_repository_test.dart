import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/network/network_status_service.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/remote/sync_api.dart';
import 'package:veriprof/data/repositories/tutoring_repository.dart';
import 'package:veriprof/data/sync/sync_engine.dart';
import 'package:veriprof/domain/usecases/tutoring_rules.dart';

/// Cours à domicile de bout en bout, sur une vraie base en mémoire.
///
/// C'est le scénario qu'un testeur fait à la main sur un seul téléphone :
/// le professeur publie, le parent réserve, le professeur accepte, et chacun
/// voit le même statut.
void main() {
  late AppDatabase db;
  late TutoringRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final sync = SyncEngine(
      database: db,
      network: NetworkStatusService(),
      api: SyncApi(Dio()),
      deviceId: 'test',
    );
    repo = TutoringRepository(db, sync);

    await db
        .into(db.subjects)
        .insert(
          SubjectsCompanion.insert(
            id: 'sub_math',
            name: 'Mathématiques',
            code: 'MATH',
          ),
        );
    for (final (id, name) in [
      ('lvl_11', '11e année'),
      ('lvl_tle', 'Terminale'),
    ]) {
      await db
          .into(db.levels)
          .insert(
            LevelsCompanion.insert(
              id: id,
              name: name,
              code: id,
              category: 'SECONDARY',
            ),
          );
    }
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'u_t',
            role: 'TEACHER',
            phone: '+224620000101',
            firstName: const Value('Mamadou'),
            lastName: const Value('Diallo'),
          ),
        );
    await db
        .into(db.teachers)
        .insert(TeachersCompanion.insert(id: 't1', userId: 'u_t'));
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'u_p',
            role: 'PARENT',
            phone: '+224600000002',
            firstName: const Value('Aïssatou'),
            lastName: const Value('Barry'),
          ),
        );
    await db
        .into(db.parents)
        .insert(
          ParentsCompanion.insert(
            id: 'p1',
            userId: 'u_p',
            district: const Value('Ratoma'),
          ),
        );
    await db
        .into(db.children)
        .insert(
          ChildrenCompanion.insert(
            id: 'c1',
            parentId: 'p1',
            firstName: 'Fatoumata',
            levelId: const Value('lvl_11'),
          ),
        );
  });

  tearDown(() => db.close());

  Future<void> declareAvailability() => repo.saveAvailability(
    teacherId: 't1',
    days: {Weekday.monday, Weekday.wednesday, Weekday.saturday},
    slots: {DaySlot.afternoon},
  );

  Future<String> publish() async {
    await declareAvailability();
    return repo.publishOffer(
      teacherId: 't1',
      subjectId: 'sub_math',
      levelIds: ['lvl_11', 'lvl_tle'],
      mode: TutoringMode.atStudent,
      hourlyRate: 60000,
      city: 'Conakry',
      districts: ['Ratoma', 'Kaloum'],
    );
  }

  test('le professeur publie, le parent voit l’offre', () async {
    final id = await publish();

    final offers = await repo.offersOf('t1', onlyActive: true);
    expect(offers, hasLength(1));
    expect(offers.single.id, id);
    expect(offers.single.teacherName, 'Mamadou Diallo');
    expect(offers.single.subjectName, 'Mathématiques');
    expect(offers.single.levelNames, ['11e année', 'Terminale']);
    expect(offers.single.districts, ['Ratoma', 'Kaloum']);
  });

  test(
    'parcours complet : réserver, accepter, même statut des deux côtés',
    () async {
      final offerId = await publish();

      await repo.requestTutoring(
        parentId: 'p1',
        offerId: offerId,
        childId: 'c1',
        message: 'Elle bloque sur les équations.',
      );

      final received = await repo.requestsOfTeacher('t1');
      expect(received, hasLength(1));
      expect(received.single.status, TutoringStatus.sent);
      expect(received.single.childName, 'Fatoumata');
      expect(received.single.childLevel, '11e année');
      expect(received.single.parentName, 'Aïssatou Barry');
      expect(received.single.parentDistrict, 'Ratoma');
      expect(received.single.message, 'Elle bloque sur les équations.');

      await repo.setStatus(
        requestId: received.single.id,
        actor: TutoringActor.teacher,
        to: TutoringStatus.accepted,
      );

      final parentSide = await repo.requestsOfParent('p1');
      expect(parentSide.single.status, TutoringStatus.accepted);
      expect(parentSide.single.respondedAt, isNotNull);
      expect(parentSide.single.offer.teacherName, 'Mamadou Diallo');
    },
  );

  test('pas de deuxième demande en cours pour le même enfant', () async {
    final offerId = await publish();
    await repo.requestTutoring(parentId: 'p1', offerId: offerId, childId: 'c1');

    expect(
      () =>
          repo.requestTutoring(parentId: 'p1', offerId: offerId, childId: 'c1'),
      throwsA(isA<TutoringException>()),
    );
  });

  test('nouvelle demande possible après annulation', () async {
    final offerId = await publish();
    final first = await repo.requestTutoring(
      parentId: 'p1',
      offerId: offerId,
      childId: 'c1',
    );
    await repo.setStatus(
      requestId: first,
      actor: TutoringActor.parent,
      to: TutoringStatus.cancelled,
    );

    await repo.requestTutoring(parentId: 'p1', offerId: offerId, childId: 'c1');
    expect(await repo.requestsOfParent('p1'), hasLength(2));
  });

  test('le parent ne peut pas accepter sa propre demande', () async {
    final offerId = await publish();
    final id = await repo.requestTutoring(
      parentId: 'p1',
      offerId: offerId,
      childId: 'c1',
    );

    expect(
      () => repo.setStatus(
        requestId: id,
        actor: TutoringActor.parent,
        to: TutoringStatus.accepted,
      ),
      throwsA(isA<TutoringException>()),
    );
    expect(
      (await repo.requestsOfParent('p1')).single.status,
      TutoringStatus.sent,
    );
  });

  test('une offre en pause ne se réserve plus', () async {
    final offerId = await publish();
    await repo.setOfferActive(offerId, active: false);

    expect(await repo.offersOf('t1', onlyActive: true), isEmpty);
    expect(await repo.offersOf('t1'), hasLength(1));
    expect(
      () =>
          repo.requestTutoring(parentId: 'p1', offerId: offerId, childId: 'c1'),
      throwsA(isA<TutoringException>()),
    );
  });

  test('une offre sans classe ni tarif est refusée', () async {
    expect(
      () => repo.publishOffer(
        teacherId: 't1',
        subjectId: 'sub_math',
        levelIds: [],
        mode: TutoringMode.online,
        hourlyRate: 50000,
        city: '',
      ),
      throwsA(isA<TutoringException>()),
    );
    expect(
      () => repo.publishOffer(
        teacherId: 't1',
        subjectId: 'sub_math',
        levelIds: ['lvl_11'],
        mode: TutoringMode.online,
        hourlyRate: 0,
        city: '',
      ),
      throwsA(isA<TutoringException>()),
    );
  });

  test('chaque écriture part dans la file de synchronisation', () async {
    final offerId = await publish();
    await repo.requestTutoring(parentId: 'p1', offerId: offerId, childId: 'c1');

    final queued = await db.select(db.syncQueue).get();
    expect(
      queued.map((q) => q.entity),
      containsAll(['tutoring_service', 'tutoring_request']),
    );
  });

  group('Disponibilité exigée avant publication', () {
    test('publier sans disponibilité est refusé', () async {
      // Une offre sans créneaux ferait réserver une famille à l'aveugle.
      expect(
        () => repo.publishOffer(
          teacherId: 't1',
          subjectId: 'sub_math',
          levelIds: ['lvl_11'],
          mode: TutoringMode.atStudent,
          hourlyRate: 50000,
          city: 'Conakry',
        ),
        throwsA(isA<TutoringException>()),
      );
    });

    test('la disponibilité se relit telle qu’elle a été enregistrée', () async {
      await declareAvailability();
      final saved = await repo.availabilityOf('t1');
      expect(saved.days, hasLength(3));
      expect(saved.days, contains(Weekday.wednesday));
      expect(saved.slots, {DaySlot.afternoon});
    });

    test('moins de trois jours est refusé à l’enregistrement', () async {
      expect(
        () => repo.saveAvailability(
          teacherId: 't1',
          days: {Weekday.monday},
          slots: {DaySlot.morning},
        ),
        throwsA(isA<TutoringException>()),
      );
    });
  });
}
